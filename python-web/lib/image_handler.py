"""Download and place images from Confluence into the Flare project.

Images are placed in dated subfolders under the "From Confluence"
Release Notes images directory, using the original Confluence
filenames to match the existing "From Confluence" convention.
"""

import logging
from pathlib import Path

from .confluence_client import ConfluenceClient

logger = logging.getLogger(__name__)

# Image media types we care about
IMAGE_TYPES = {"image/png", "image/jpeg", "image/gif", "image/svg+xml", "image/webp"}


def _get_media_type(attachment: dict) -> str:
    """Extract mediaType from a Confluence attachment dict.

    The REST API v1 nests mediaType under 'extensions' or 'metadata',
    NOT at the top level.
    """
    return (attachment.get("extensions", {}).get("mediaType", "")
            or attachment.get("metadata", {}).get("mediaType", ""))


def create_image_folder(images_base: Path, folder_name: str) -> Path:
    """Create the dated image folder if it doesn't exist.

    Args:
        images_base: Base images directory, e.g.
                     .../Content/Resources/From Confluence/Release Notes
        folder_name: Date-based folder name, e.g. "05-Jan-2026"

    Returns:
        Path to the created folder.
    """
    folder = images_base / folder_name
    folder.mkdir(parents=True, exist_ok=True)
    return folder


def download_and_place_images(
    client: ConfluenceClient,
    page_id: str,
    dest_folder: Path,
) -> dict[str, str]:
    """Download all image attachments from a Confluence page.

    Images are saved with sequential names (image1.png, image2.png, ...)
    to match the existing Flare convention.

    Args:
        client: Authenticated Confluence client.
        page_id: Confluence page ID.
        dest_folder: Local folder to save images into.

    Returns:
        Mapping of {confluence_filename: local_filename} for use by
        the content converter when rewriting image references.
    """
    attachments = client.get_page_attachments(page_id)
    image_attachments = [
        a for a in attachments
        if _get_media_type(a) in IMAGE_TYPES
    ]

    if not image_attachments:
        logger.info("  No image attachments found")
        return {}

    logger.info("  Downloading %d image(s)...", len(image_attachments))
    mapping = {}

    for attachment in image_attachments:
        confluence_name = attachment["title"]
        # Use original Confluence filename to match "From Confluence" convention
        local_name = confluence_name

        download_path = attachment["_links"]["download"]
        dest_file = dest_folder / local_name

        client.download_attachment(download_path, dest_file)
        mapping[confluence_name] = local_name
        logger.info("    %s", confluence_name)

    return mapping
