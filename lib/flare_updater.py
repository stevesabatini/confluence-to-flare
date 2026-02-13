"""Update Flare project files (Overview page and Mini-TOC) when new
release notes are imported.

Uses BeautifulSoup XML parser for safe, non-destructive edits to
existing Flare project XML files.  New entries are inserted in
date order (newest-first) regardless of import order.
"""

import logging
import re
from datetime import datetime
from pathlib import Path

from bs4 import BeautifulSoup

logger = logging.getLogger(__name__)

# BOM for Flare XML files
BOM = "\ufeff"

# Pattern to extract date from Flare release note filenames
# Matches: "Release Notes 2026-Jan-05.htm" → year=2026, month=Jan, day=05
# Uses re.search so it works on both bare filenames and full paths
_FILENAME_DATE_RE = re.compile(r"Release Notes (\d{4})-([A-Za-z]{3})-(\d{2})\.htm")


def _parse_date_from_filename(filename: str) -> datetime | None:
    """Extract a datetime from a Flare release notes filename.

    Args:
        filename: A string like "Release Notes 2026-Jan-05.htm"
                  or a path containing such a filename.

    Returns:
        datetime object, or None if the filename doesn't match.
    """
    match = _FILENAME_DATE_RE.search(filename)
    if not match:
        return None
    try:
        return datetime.strptime(
            f"{match.group(1)}-{match.group(2)}-{match.group(3)}",
            "%Y-%b-%d",
        )
    except ValueError:
        return None


def update_overview_page(
    overview_path: Path,
    filename: str,
    link_text: str,
    release_date: datetime,
) -> None:
    """Insert a new release note link in date order on the Overview page.

    Adds a new <li><p><a href="...">Release: Month DD, YYYY</a></p></li>
    in the correct position within the <ul> under "Recent Releases",
    maintaining newest-first date ordering.

    Args:
        overview_path: Path to Release Notes Overview.htm
        filename: HTM filename, e.g. "Release Notes 2026-Jan-05.htm"
        link_text: Display text, e.g. "Release: January 5, 2026"
        release_date: The date of this release note for sort positioning.
    """
    raw = overview_path.read_text(encoding="utf-8-sig")
    soup = BeautifulSoup(raw, "html.parser")

    # Find the <ul> that contains release links
    ul = soup.find("ul")
    if not ul:
        logger.error("Could not find <ul> in overview page")
        return

    # Build the new list item matching the existing format:
    # <li><p><a href="Release Notes YYYY-MMM-DD.htm">Release: Month DD, YYYY</a></p></li>
    new_li = soup.new_tag("li")
    new_p = soup.new_tag("p")
    new_a = soup.new_tag("a", href=filename)
    new_a.string = link_text
    new_p.append(new_a)
    new_li.append(new_p)

    # Find correct insertion point (newest-first order)
    existing_items = ul.find_all("li")
    insert_before = None

    for li in existing_items:
        a_tag = li.find("a", href=True)
        if not a_tag:
            continue
        existing_date = _parse_date_from_filename(a_tag["href"])
        if existing_date is None:
            # Unparseable entries treated as oldest — skip past them
            continue
        if existing_date < release_date:
            # Found the first entry older than the new one — insert before it
            insert_before = li
            break

    if insert_before:
        insert_before.insert_before(new_li)
        insert_before.insert_before("\n            ")
    else:
        # New entry is older than all existing entries (or list is empty)
        if existing_items:
            last_li = existing_items[-1]
            last_li.insert_after("\n            ")
            last_li.insert_after(new_li)
        else:
            ul.append(new_li)

    # Write back with BOM
    output = BOM + str(soup)
    overview_path.write_text(output, encoding="utf-8")
    logger.info("Updated overview page with link to %s", filename)


def update_mini_toc(
    toc_path: Path,
    filename: str,
    toc_title: str,
    release_date: datetime,
) -> None:
    """Insert a new TocEntry in date order in the Mini-TOC.

    Adds a <TocEntry> in the correct position under the "Release Notes"
    parent entry, maintaining newest-first date ordering.  The entry is
    always placed before the "Release Notes Archive" entry if one exists.

    Args:
        toc_path: Path to Visualization Guide Mini-TOC.fltoc
        filename: HTM filename, e.g. "Release Notes 2026-Jan-05.htm"
        toc_title: Title for the entry, e.g. "January 5, 2026"
        release_date: The date of this release note for sort positioning.
    """
    raw = toc_path.read_text(encoding="utf-8-sig")
    soup = BeautifulSoup(raw, "xml")

    # Find the Release Notes parent TocEntry
    release_notes_entry = None
    for entry in soup.find_all("TocEntry"):
        if entry.get("Title") == "Release Notes":
            release_notes_entry = entry
            break

    if not release_notes_entry:
        logger.error("Could not find 'Release Notes' TocEntry in Mini-TOC")
        return

    # Build the new TocEntry
    link = f"/Content/E_Landing Topics/Release Notes/{filename}"
    new_entry = soup.new_tag("TocEntry")
    new_entry["Title"] = toc_title
    new_entry["Link"] = link

    # Collect direct child TocEntry elements
    children = release_notes_entry.find_all("TocEntry", recursive=False)

    # Find correct insertion point (newest-first, before Archive)
    insert_before = None
    for child in children:
        child_link = child.get("Link", "")
        if not child_link:
            # Entry with no Link (e.g. Archive) — always insert before it
            insert_before = child
            break
        existing_date = _parse_date_from_filename(child_link)
        if existing_date is None:
            # Unparseable; skip past it
            continue
        if existing_date < release_date:
            # Found the first entry older than the new one
            insert_before = child
            break

    if insert_before:
        insert_before.insert_before(new_entry)
        insert_before.insert_before("\n    ")
    else:
        # New entry is older than everything and there's no Archive
        release_notes_entry.append("\n    ")
        release_notes_entry.append(new_entry)

    # Write back with BOM
    output = BOM + str(soup)
    toc_path.write_text(output, encoding="utf-8")
    logger.info("Updated Mini-TOC with entry for %s", filename)
