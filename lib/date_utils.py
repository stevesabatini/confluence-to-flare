"""Date parsing and formatting for Confluence → Flare conversion.

Handles Confluence page title formats like:
  "COG Release Features(Production)-05thJan'26"         (2-digit year)
  "COG Technical Release Notes(Production)-27thJan'26"  (2-digit year)
  "COG_Technical Release Notes-02ndNov'2020"             (4-digit year, older)
  "COG Technical Release Notes(Production)-08thJan'2024" (4-digit year, newer)
  "COG Technical Patch Release Notes(Production)-13thJan'26"

And converts to Flare naming conventions like:
  Filename: "Release Notes 2026-Jan-05.htm"
  Image folder: "05-Jan-2026"
  Display: "January 5, 2026"
"""

import re
from datetime import datetime


# Primary pattern: day with ordinal suffix + 3-letter month + year
#   "05thJan'26", "02ndNov'2020", "08thJan'2024"
_DATE_PATTERN = re.compile(
    r"(\d{1,2})(?:st|nd|rd|th)"       # day with ordinal suffix
    r"([A-Za-z]{3,9})"                # month (3-letter abbrev or full name)
    r"'(\d{2,4})$"                     # 2-or-4-digit year with apostrophe
)

# Fallback pattern: day WITHOUT ordinal suffix + 3-letter month + year
#   "03Jun'2024", "05Aug'2024"
_DATE_PATTERN_NO_ORDINAL = re.compile(
    r"(\d{1,2})"                       # day (no ordinal suffix)
    r"([A-Z][a-z]{2})"                # 3-letter month abbreviation
    r"'(\d{2,4})$"                     # 2-or-4-digit year with apostrophe
)

# Edge case pattern: day with ordinal before apostrophe-month
#   "15th'Dec2021"
_DATE_PATTERN_ALT = re.compile(
    r"(\d{1,2})(?:st|nd|rd|th)"       # day with ordinal suffix
    r"'([A-Z][a-z]{2})"              # month with leading apostrophe
    r"(\d{4})$"                        # 4-digit year
)

# Map full month names to 3-letter abbreviations
_MONTH_NORMALIZE = {
    "january": "Jan", "february": "Feb", "march": "Mar",
    "april": "Apr", "may": "May", "june": "Jun",
    "july": "Jul", "august": "Aug", "september": "Sep",
    "october": "Oct", "november": "Nov", "december": "Dec",
}


def _normalize_month(month_str: str) -> str:
    """Convert a month string (3-letter, full name, any case) to 3-letter title case."""
    lower = month_str.lower()
    # Check full month names first
    if lower in _MONTH_NORMALIZE:
        return _MONTH_NORMALIZE[lower]
    # Already a 3-letter abbreviation — title-case it
    return month_str.capitalize()[:3]


def parse_confluence_title(title: str) -> datetime | None:
    """Extract a date from a Confluence release note page title.

    Handles various naming conventions used across years:
      "COG Release Features(Production)-05thJan'26"         (standard)
      "COG_Technical Release Notes-02ndNov'2020"             (4-digit year)
      "COG Technical Release Notes(Production)-22ndApril'2024" (full month)
      "COG Release Features(Production)-03Jun'2024"          (no ordinal)
      "COG_ReleaseFeatures-21stNOV'2022"                     (uppercase month)
      "COG_ReleaseFeatures_15th'Dec2021"                     (apostrophe before month)

    Returns:
        datetime object, or None if title doesn't match expected format.
    """
    title = title.strip()

    # Try primary pattern (with ordinal suffix)
    match = _DATE_PATTERN.search(title)
    if match:
        day_str, month_raw, year_str = match.groups()
    else:
        # Try fallback pattern (no ordinal suffix, e.g. "03Jun'2024")
        match = _DATE_PATTERN_NO_ORDINAL.search(title)
        if match:
            day_str, month_raw, year_str = match.groups()
        else:
            # Try alt pattern (apostrophe before month, e.g. "15th'Dec2021")
            match = _DATE_PATTERN_ALT.search(title)
            if match:
                day_str, month_raw, year_str = match.groups()
            else:
                return None

    day = int(day_str)
    month_abbr = _normalize_month(month_raw)

    if len(year_str) == 2:
        year = 2000 + int(year_str)
    else:
        year = int(year_str)

    try:
        return datetime.strptime(f"{day} {month_abbr} {year}", "%d %b %Y")
    except ValueError:
        return None


def format_flare_filename(dt: datetime) -> str:
    """Format date as Flare release note filename.

    Example: datetime(2026, 1, 5) → "Release Notes 2026-Jan-05.htm"
    """
    return f"Release Notes {dt.strftime('%Y-%b-%d')}.htm"


def format_image_folder(dt: datetime) -> str:
    """Format date as image subfolder name.

    Example: datetime(2026, 1, 5) → "05-Jan-2026"
    """
    return dt.strftime("%d-%b-%Y")


def format_display_date(dt: datetime) -> str:
    """Format date for display in H1 heading and overview links.

    Example: datetime(2026, 1, 5) → "January 5, 2026"
    """
    return f"{dt.strftime('%B')} {dt.day}, {dt.year}"


def format_toc_title(dt: datetime) -> str:
    """Format date for TOC entry Title attribute.

    Example: datetime(2026, 1, 5) → "January 5, 2026"
    """
    return format_display_date(dt)


def format_overview_link_text(dt: datetime) -> str:
    """Format the link text used in the Overview page.

    Example: datetime(2026, 1, 5) → "Release: January 5, 2026"
    """
    return f"Release: {format_display_date(dt)}"
