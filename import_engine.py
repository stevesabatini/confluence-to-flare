"""Generator-based import engine for the web UI.

Wraps the existing lib/ modules into a generator that yields structured
progress events. Each event is a dict that the Flask app converts to
an SSE data line for the browser.

This module does NOT modify any existing lib/ code — it imports and
calls the same functions the CLI uses.
"""

import logging
from pathlib import Path
from typing import Generator

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


def validate_config(config_path: Path) -> dict:
    """Load and validate config.yaml, returning result dict.

    Unlike the CLI's load_config(), this does NOT call sys.exit().
    Returns {"valid": True, "config": {...}} or {"valid": False, "error": "..."}.
    """
    if not config_path.exists():
        return {
            "valid": False,
            "error": "Config file not found. Copy config.yaml.example to config.yaml and fill in your credentials.",
        }

    try:
        with open(config_path, encoding="utf-8") as f:
            config = yaml.safe_load(f)
    except Exception as e:
        return {"valid": False, "error": f"Failed to parse config.yaml: {e}"}

    conf = config.get("confluence", {})
    for field in ("base_url", "email", "api_token", "production_parent_id"):
        if not conf.get(field):
            return {
                "valid": False,
                "error": f"Missing required field: confluence.{field}",
            }

    flare = config.get("flare_project", {})
    if not flare.get("root"):
        return {
            "valid": False,
            "error": "Missing required field: flare_project.root",
        }

    return {"valid": True, "config": config}


def resolve_paths(config: dict, script_dir: Path) -> dict:
    """Resolve all Flare project paths relative to script directory.

    Same logic as confluence_to_flare.resolve_flare_paths().
    """
    flare = config["flare_project"]
    root = (script_dir / flare["root"]).resolve()

    return {
        "root": root,
        "release_notes_dir": root / flare.get(
            "release_notes_dir",
            "Content/E_Landing Topics/Release Notes",
        ),
        "images_dir": root / flare.get(
            "images_dir",
            "Content/Resources/From Confluence/Release Notes",
        ),
        "overview_file": root / flare.get(
            "overview_file",
            "Content/E_Landing Topics/Release Notes/Release Notes Overview.htm",
        ),
        "toc_file": root / flare.get(
            "toc_file",
            "Project/TOCs/Landing Topic Mini TOCs/Visualization Guide Mini-TOC.fltoc",
        ),
    }


def get_existing_releases(release_notes_dir: Path) -> set[str]:
    """Get filenames of existing release note HTM files."""
    if not release_notes_dir.exists():
        return set()
    return {f.name for f in release_notes_dir.glob("Release Notes *.htm")}


def create_client(config: dict) -> ConfluenceClient:
    """Create an authenticated Confluence client from config."""
    conf = config["confluence"]
    return ConfluenceClient(conf["base_url"], conf["email"], conf["api_token"])


def run_import(
    page_ids: list[str],
    config: dict,
    script_dir: Path,
    force: bool = False,
) -> Generator[dict, None, None]:
    """Run the import pipeline, yielding progress events.

    Args:
        page_ids: List of Confluence page IDs to import.
        config: Validated config dict (from validate_config).
        script_dir: Path to the confluence_to_flare directory.
        force: If True, overwrite existing Flare files.

    Yields:
        Progress event dicts with "type" and other fields.
    """
    total = len(page_ids)
    yield {"type": "start", "total": total, "message": f"Starting import of {total} page(s)"}

    # Setup
    try:
        paths = resolve_paths(config, script_dir)
        if not paths["root"].exists():
            yield {"type": "error", "index": -1, "message": f"Flare project not found at {paths['root']}"}
            yield {"type": "complete", "imported": 0, "skipped": 0, "errors": 1, "message": "Import failed"}
            return

        client = create_client(config)
        template_dir = script_dir / "templates"
        env = Environment(loader=FileSystemLoader(str(template_dir)))
        template = env.get_template("release_note.htm.j2")
        existing = get_existing_releases(paths["release_notes_dir"])
    except Exception as e:
        yield {"type": "error", "index": -1, "message": f"Setup failed: {e}"}
        yield {"type": "complete", "imported": 0, "skipped": 0, "errors": 1, "message": "Import failed"}
        return

    imported_count = 0
    skipped_count = 0
    error_count = 0

    for i, page_id in enumerate(page_ids):
        try:
            # Fetch title
            title = client.get_page_title(page_id)
            yield {
                "type": "page_start",
                "index": i,
                "page_id": page_id,
                "title": title,
                "message": f"Importing: {title}",
            }

            # Parse date
            dt = parse_confluence_title(title)
            if not dt:
                yield {"type": "error", "index": i, "message": f"Could not parse date from title: {title}"}
                error_count += 1
                continue

            filename = format_flare_filename(dt)
            display_date = format_display_date(dt)
            image_folder_name = format_image_folder(dt)

            # Check if already exists
            if filename in existing and not force:
                yield {"type": "skip", "index": i, "filename": filename, "message": f"Already exists: {filename}"}
                skipped_count += 1
                continue

            # Step 1: Download images
            yield {"type": "step", "index": i, "step": "images", "message": "Downloading images..."}
            image_dest = create_image_folder(paths["images_dir"], image_folder_name)
            image_mapping = download_and_place_images(client, page_id, image_dest)
            img_count = len(image_mapping)
            yield {"type": "step", "index": i, "step": "images_done", "message": f"Downloaded {img_count} image(s)"}

            # Step 2: Fetch and convert content
            yield {"type": "step", "index": i, "step": "content", "message": "Converting page content..."}
            xhtml = client.get_page_content(page_id)
            body_content = convert_content(xhtml, image_mapping, image_folder_name)
            yield {"type": "step", "index": i, "step": "content_done", "message": "Converted page content"}

            # Step 3: Render template
            yield {"type": "step", "index": i, "step": "render", "message": "Rendering Flare topic..."}
            htm = template.render(
                display_date=display_date,
                body_content=body_content,
            )
            yield {"type": "step", "index": i, "step": "render_done", "message": "Rendered Flare topic"}

            # Step 4: Write HTM file
            yield {"type": "step", "index": i, "step": "write", "message": f"Writing {filename}..."}
            dest_file = paths["release_notes_dir"] / filename
            dest_file.parent.mkdir(parents=True, exist_ok=True)
            dest_file.write_text(BOM + htm, encoding="utf-8")
            yield {"type": "step", "index": i, "step": "write_done", "message": f"Wrote {filename}"}

            # Step 5: Update Overview page
            yield {"type": "step", "index": i, "step": "overview", "message": "Updating Overview page..."}
            update_overview_page(
                paths["overview_file"],
                filename,
                format_overview_link_text(dt),
                release_date=dt,
            )
            yield {"type": "step", "index": i, "step": "overview_done", "message": "Updated Overview page"}

            # Step 6: Update Mini-TOC
            yield {"type": "step", "index": i, "step": "toc", "message": "Updating Mini-TOC..."}
            update_mini_toc(
                paths["toc_file"],
                filename,
                format_toc_title(dt),
                release_date=dt,
            )
            yield {"type": "step", "index": i, "step": "toc_done", "message": "Updated Mini-TOC"}

            # Page complete
            yield {
                "type": "page_done",
                "index": i,
                "filename": filename,
                "message": f"Complete: {filename}",
            }
            imported_count += 1

        except Exception as e:
            logger.exception("Error importing page %s", page_id)
            yield {"type": "error", "index": i, "message": str(e)}
            error_count += 1

    # Final summary
    yield {
        "type": "complete",
        "imported": imported_count,
        "skipped": skipped_count,
        "errors": error_count,
        "message": f"Import complete: {imported_count} imported, {skipped_count} skipped, {error_count} error(s)",
    }
