"""Confluence Cloud REST API client.

Uses basic auth (email + API token) to fetch release note pages,
their content in storage format (XHTML), and image attachments.
"""

import time
import logging
from pathlib import Path

import requests

logger = logging.getLogger(__name__)


class ConfluenceClient:
    """Client for Confluence Cloud REST API."""

    def __init__(self, base_url: str, email: str, api_token: str):
        self.base_url = base_url.rstrip("/")
        self.session = requests.Session()
        self.session.auth = (email, api_token)
        self.session.headers.update({"Accept": "application/json"})

    # ── Core request with retry ──────────────────────────────────────

    def _get(self, url: str, params: dict | None = None) -> dict:
        """GET request with exponential backoff on 429."""
        for attempt in range(5):
            resp = self.session.get(url, params=params)
            if resp.status_code == 429:
                wait = 2 ** attempt
                logger.warning("Rate limited (429), waiting %ds...", wait)
                time.sleep(wait)
                continue
            resp.raise_for_status()
            return resp.json()
        raise RuntimeError("Rate limit exceeded after 5 retries")

    # ── Page operations (REST API v2) ────────────────────────────────

    def get_child_pages(self, page_id: str) -> list[dict]:
        """Fetch all immediate child pages of a given page.

        Returns list of dicts with keys: id, title, status.
        Handles cursor-based pagination automatically.
        """
        url = f"{self.base_url}/wiki/api/v2/pages/{page_id}/children"
        all_pages = []
        params = {"limit": 50}

        while True:
            data = self._get(url, params=params)
            all_pages.extend(data.get("results", []))

            next_link = data.get("_links", {}).get("next")
            if not next_link:
                break
            # next_link is a relative path; build full URL
            url = f"{self.base_url}{next_link}"
            params = None  # params are embedded in next_link

        return all_pages

    def get_release_feature_pages(self, production_parent_id: str) -> list[dict]:
        """Walk the Confluence hierarchy to find all customer-facing release pages.

        Expected hierarchy:
          Production Environment (production_parent_id)
            → Production-YYYY folders
              → COG Technical Release Notes(Production)-*
                → COG Release Features(Production)-*  ← primary target
              → COG Technical Patch Release Notes(Production)-*  ← also included

        For Technical Release Notes that have a Features child page, we
        return the Features child (that's the customer-facing content).
        For ones with no Features child, we return the Technical page itself
        (some years store content directly on it).
        Patch pages are leaf pages and are returned directly.

        Only pages matching known release-note naming patterns are included.
        Everything else is silently skipped.

        Returns list of dicts: {id, title, type} where type is
        "features" or "patch".
        """
        result = []

        # Level 1: Get Production-YYYY year folders
        year_folders = self.get_child_pages(production_parent_id)

        # Filter to only Production-YYYY / Production Releases-YYYY folders
        year_folders = [
            f for f in year_folders
            if f["title"].lower().startswith("production")
        ]
        logger.info("Found %d year folder(s) under Production Environment",
                     len(year_folders))

        for year_folder in year_folders:
            year_title = year_folder["title"]
            logger.info("  Scanning %s...", year_title)

            # Level 2: Get release note pages within the year folder
            release_pages = self.get_child_pages(year_folder["id"])

            for page in release_pages:
                title = page["title"]

                if "Patch" in title and "Release Notes" in title:
                    # Patch release notes are leaf pages (no Features child)
                    result.append({
                        "id": page["id"],
                        "title": title,
                        "type": "patch",
                    })
                    logger.info("    Found patch: %s", title)

                elif "Technical Release Notes" in title or "Technical_Release Notes" in title:
                    # Technical release notes may have a Features child page
                    children = self.get_child_pages(page["id"])
                    features_children = [
                        c for c in children
                        if "Features" in c["title"] or "Release Features" in c["title"]
                    ]

                    if features_children:
                        # Use the Features child page (customer-facing content)
                        for child in features_children:
                            result.append({
                                "id": child["id"],
                                "title": child["title"],
                                "type": "features",
                            })
                            logger.info("    Found features: %s", child["title"])
                    else:
                        # No Features child — content is on the Technical page itself
                        result.append({
                            "id": page["id"],
                            "title": title,
                            "type": "features",
                        })
                        logger.info("    Found features (no child): %s", title)

                else:
                    # Skip non-release-note pages silently
                    logger.debug("    Skipping non-release page: %s", title)

        return result

    def get_page_content(self, page_id: str) -> str:
        """Fetch page body in storage format (XHTML).

        Returns the raw XHTML string from Confluence storage format.
        """
        url = f"{self.base_url}/wiki/api/v2/pages/{page_id}"
        params = {"body-format": "storage"}
        data = self._get(url, params=params)
        return data.get("body", {}).get("storage", {}).get("value", "")

    def get_page_title(self, page_id: str) -> str:
        """Fetch just the page title."""
        url = f"{self.base_url}/wiki/api/v2/pages/{page_id}"
        data = self._get(url)
        return data.get("title", "")

    # ── Attachment operations (REST API v1 for downloads) ────────────

    def get_page_attachments(self, page_id: str) -> list[dict]:
        """List all attachments on a page.

        Returns list of dicts with keys: title (filename), mediaType,
        fileSize, _links.download.
        """
        url = (f"{self.base_url}/wiki/rest/api/content/{page_id}"
               f"/child/attachment")
        params = {"limit": 100, "expand": "version"}
        all_attachments = []

        while True:
            data = self._get(url, params=params)
            all_attachments.extend(data.get("results", []))

            next_link = data.get("_links", {}).get("next")
            if not next_link:
                break
            url = f"{self.base_url}{next_link}"
            params = None

        return all_attachments

    def download_attachment(self, download_path: str, dest: Path) -> None:
        """Download an attachment binary to a local file.

        Args:
            download_path: The _links.download value from the attachment.
            dest: Local Path to write the file to.
        """
        url = f"{self.base_url}/wiki{download_path}"
        resp = self.session.get(url, stream=True)
        resp.raise_for_status()

        dest.parent.mkdir(parents=True, exist_ok=True)
        with open(dest, "wb") as f:
            for chunk in resp.iter_content(chunk_size=8192):
                f.write(chunk)
