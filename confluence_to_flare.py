#!/usr/bin/env python3
"""Confluence → MadCap Flare Release Notes Importer.

Pulls release note pages from Confluence Cloud, converts them to
Flare-compatible HTM topics, downloads images, and updates the
project's Overview page and Mini-TOC.

Usage:
    python confluence_to_flare.py                    # Import all new releases
    python confluence_to_flare.py --dry-run           # Preview without writing
    python confluence_to_flare.py --page-id 12345     # Import a single page
    python confluence_to_flare.py --since 2025-01-01  # Only pages after a date
    python confluence_to_flare.py --force             # Re-import existing
"""

import argparse
import logging
import sys
from datetime import datetime
from pathlib import Path

import yaml
from jinja2 import Environment, FileSystemLoader

from lib.confluence_client import ConfluenceClient
from lib.content_converter import convert_content
from lib.date_utils import (
    format_display_date,
    format_flare_filename,
    format_image_folder,
    format_overview_link_text,
    format_toc_title,
    parse_confluence_title,
)
from lib.flare_updater import update_mini_toc, update_overview_page
from lib.image_handler import create_image_folder, download_and_place_images

logger = logging.getLogger(__name__)

# BOM character for Flare HTM files
BOM = "\ufeff"


def load_config(config_path: Path) -> dict:
    """Load and validate the YAML config file."""
    if not config_path.exists():
        print(f"Error: Config file not found at {config_path}")
        print(f"Copy config.yaml.example to config.yaml and fill in your credentials.")
        sys.exit(1)

    with open(config_path, encoding="utf-8") as f:
        config = yaml.safe_load(f)

    # Validate required fields
    conf = config.get("confluence", {})
    for field in ("base_url", "email", "api_token", "production_parent_id"):
        if not conf.get(field):
            print(f"Error: confluence.{field} is required in config.yaml")
            sys.exit(1)

    flare = config.get("flare_project", {})
    if not flare.get("root"):
        print("Error: flare_project.root is required in config.yaml")
        sys.exit(1)

    return config


def resolve_flare_paths(config: dict, script_dir: Path) -> dict:
    """Resolve all Flare project paths relative to the script directory."""
    flare = config["flare_project"]
    root = (script_dir / flare["root"]).resolve()

    return {
        "root": root,
        "release_notes_dir": root / flare.get("release_notes_dir",
                                                "Content/E_Landing Topics/Release Notes"),
        "images_dir": root / flare.get("images_dir",
                                        "Content/Resources/From Confluence/Release Notes"),
        "overview_file": root / flare.get("overview_file",
                                           "Content/E_Landing Topics/Release Notes/Release Notes Overview.htm"),
        "toc_file": root / flare.get("toc_file",
                                      "Project/TOCs/Landing Topic Mini TOCs/Visualization Guide Mini-TOC.fltoc"),
    }


def get_existing_releases(release_notes_dir: Path) -> set[str]:
    """Get filenames of existing release note HTM files."""
    if not release_notes_dir.exists():
        return set()
    return {f.name for f in release_notes_dir.glob("Release Notes *.htm")}


def import_page(
    client: ConfluenceClient,
    page: dict,
    paths: dict,
    template: object,
    dry_run: bool = False,
) -> str | None:
    """Import a single Confluence page as a Flare release note topic.

    Returns the generated filename, or None if skipped.
    """
    title = page["title"]
    page_id = page["id"]

    # Parse date from title
    dt = parse_confluence_title(title)
    if not dt:
        logger.warning("Could not parse date from title: %s — skipping", title)
        return None

    filename = format_flare_filename(dt)
    display_date = format_display_date(dt)
    image_folder_name = format_image_folder(dt)

    logger.info("Importing: %s → %s", title, filename)

    if dry_run:
        logger.info("  [DRY RUN] Would create %s", filename)
        return filename

    # 1. Download images
    image_dest = create_image_folder(paths["images_dir"], image_folder_name)
    image_mapping = download_and_place_images(client, page_id, image_dest)

    # 2. Fetch and convert page content
    xhtml = client.get_page_content(page_id)
    body_content = convert_content(xhtml, image_mapping, image_folder_name)

    # 3. Render Flare topic from template
    htm = template.render(
        display_date=display_date,
        body_content=body_content,
    )

    # 4. Write the HTM file with BOM
    dest_file = paths["release_notes_dir"] / filename
    dest_file.write_text(BOM + htm, encoding="utf-8")
    logger.info("  Wrote %s", dest_file)

    return filename


def main():
    parser = argparse.ArgumentParser(
        description="Import Confluence release notes into MadCap Flare"
    )
    parser.add_argument(
        "--dry-run", action="store_true",
        help="Preview what would be imported without writing files"
    )
    parser.add_argument(
        "--force", action="store_true",
        help="Re-import releases that already exist in Flare"
    )
    parser.add_argument(
        "--page-id",
        help="Import a single Confluence page by its ID"
    )
    parser.add_argument(
        "--since",
        help="Only import pages with dates after YYYY-MM-DD"
    )
    parser.add_argument(
        "--no-toc", action="store_true",
        help="Skip updating the Mini-TOC"
    )
    parser.add_argument(
        "--no-overview", action="store_true",
        help="Skip updating the Overview page"
    )
    parser.add_argument(
        "--config", default="config.yaml",
        help="Path to config file (default: config.yaml)"
    )
    parser.add_argument(
        "--verbose", "-v", action="store_true",
        help="Enable verbose logging"
    )
    args = parser.parse_args()

    # Setup logging
    log_level = logging.DEBUG if args.verbose else logging.INFO
    logging.basicConfig(
        level=log_level,
        format="%(message)s",
    )

    # Load config
    script_dir = Path(__file__).parent
    config = load_config(script_dir / args.config)
    paths = resolve_flare_paths(config, script_dir)

    # Verify Flare project exists
    if not paths["root"].exists():
        logger.error("Flare project not found at %s", paths["root"])
        sys.exit(1)

    # Initialize Confluence client
    conf = config["confluence"]
    client = ConfluenceClient(conf["base_url"], conf["email"], conf["api_token"])

    # Load Jinja2 template
    template_dir = script_dir / "templates"
    env = Environment(loader=FileSystemLoader(str(template_dir)))
    template = env.get_template("release_note.htm.j2")

    # Get existing releases (to skip unless --force)
    existing = get_existing_releases(paths["release_notes_dir"])
    logger.info("Found %d existing release note(s) in Flare", len(existing))

    # Fetch pages from Confluence
    if args.page_id:
        # Single page mode
        title = client.get_page_title(args.page_id)
        pages = [{"id": args.page_id, "title": title, "type": "features"}]
        logger.info("Single page mode: %s", title)
    else:
        # Walk the hierarchy
        logger.info("Fetching release notes from Confluence...")
        pages = client.get_release_feature_pages(conf["production_parent_id"])
        logger.info("Found %d release page(s)", len(pages))

    # Filter by --since date
    since_dt = None
    if args.since:
        since_dt = datetime.strptime(args.since, "%Y-%m-%d")

    # Import each page
    imported = []
    skipped = []

    for page in pages:
        dt = parse_confluence_title(page["title"])
        if not dt:
            logger.warning("Skipping (can't parse date): %s", page["title"])
            skipped.append(page["title"])
            continue

        filename = format_flare_filename(dt)

        # Skip if already exists (unless --force)
        if filename in existing and not args.force:
            logger.info("Skipping (already exists): %s", filename)
            skipped.append(page["title"])
            continue

        # Skip if before --since date
        if since_dt and dt < since_dt:
            logger.info("Skipping (before --since): %s", page["title"])
            skipped.append(page["title"])
            continue

        result = import_page(client, page, paths, template, dry_run=args.dry_run)
        if result:
            imported.append((result, dt))

    # Sort imported by date (newest first) for TOC/Overview updates
    imported.sort(key=lambda x: x[1], reverse=True)

    # Update project files
    if imported and not args.dry_run:
        for filename, dt in imported:
            if not args.no_overview:
                update_overview_page(
                    paths["overview_file"],
                    filename,
                    format_overview_link_text(dt),
                    release_date=dt,
                )
            if not args.no_toc:
                update_mini_toc(
                    paths["toc_file"],
                    filename,
                    format_toc_title(dt),
                    release_date=dt,
                )

    # Print summary
    print()
    print("=" * 60)
    if args.dry_run:
        print("DRY RUN SUMMARY")
    else:
        print("IMPORT SUMMARY")
    print("=" * 60)
    print(f"  Imported: {len(imported)}")
    print(f"  Skipped:  {len(skipped)}")

    if imported:
        print()
        print("Imported files:")
        for filename, dt in imported:
            print(f"  - {filename}")

    if imported and not args.dry_run:
        print()
        print("Next steps:")
        print("  1. Open the Flare project and preview the imported topics")
        print("  2. Run a Flare build to verify everything compiles")
        print("  3. Review the Overview page and Mini-TOC for correct ordering")

    print()


if __name__ == "__main__":
    main()
