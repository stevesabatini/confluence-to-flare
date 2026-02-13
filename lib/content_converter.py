"""Convert Confluence storage format XHTML to Flare-compatible HTML.

Handles Confluence-specific elements (ac:image, ac:structured-macro,
ac:layout, ri:attachment, etc.) and converts them to clean HTML that
works in MadCap Flare topics.
"""

import re
import logging

from bs4 import BeautifulSoup, Tag, NavigableString

logger = logging.getLogger(__name__)


def convert_content(
    xhtml: str,
    image_mapping: dict[str, str],
    image_folder: str,
) -> str:
    """Convert Confluence storage format XHTML to Flare body HTML.

    Args:
        xhtml: Raw XHTML from Confluence storage format.
        image_mapping: {confluence_filename: local_filename} from image handler.
        image_folder: Date-based folder name for image paths, e.g. "05-Jan-2026".

    Returns:
        Clean HTML string suitable for insertion into Flare topic <body>.
    """
    soup = BeautifulSoup(xhtml, "html.parser")

    _convert_images(soup, image_mapping, image_folder)
    _convert_macros(soup)
    _unwrap_layouts(soup)
    _demote_h1_to_h2(soup)
    _strip_attributes(soup)
    _remove_empty_paragraphs(soup)

    return _serialize(soup)


def _convert_images(
    soup: BeautifulSoup,
    image_mapping: dict[str, str],
    image_folder: str,
) -> None:
    """Replace ac:image elements with standard <img> tags."""
    for ac_image in soup.find_all("ac:image"):
        # Find the attachment reference inside
        ri_attachment = ac_image.find("ri:attachment")
        if ri_attachment:
            confluence_name = ri_attachment.get("ri:filename", "")
            local_name = image_mapping.get(confluence_name, confluence_name)
            src = f"../../Resources/From Confluence/Release Notes/{image_folder}/{local_name}"

            img_tag = soup.new_tag("img", src=src)
            # Preserve any width/height from the ac:image
            if ac_image.get("ac:width"):
                img_tag["style"] = f"width: {ac_image['ac:width']}px;"

            ac_image.replace_with(img_tag)
        else:
            # External image URL
            ri_url = ac_image.find("ri:url")
            if ri_url:
                url = ri_url.get("ri:value", "")
                img_tag = soup.new_tag("img", src=url)
                ac_image.replace_with(img_tag)
            else:
                ac_image.decompose()


def _convert_macros(soup: BeautifulSoup) -> None:
    """Convert ac:structured-macro elements to Flare equivalents."""
    for macro in soup.find_all("ac:structured-macro"):
        macro_name = macro.get("ac:name", "")

        if macro_name in ("info", "note"):
            _macro_to_callout(soup, macro, "note", "Note: ")
        elif macro_name == "warning":
            _macro_to_callout(soup, macro, "warning", "Warning: ")
        elif macro_name == "tip":
            _macro_to_callout(soup, macro, "tip", "Tip: ")
        elif macro_name == "code" or macro_name == "noformat":
            _macro_to_code(soup, macro)
        elif macro_name == "toc":
            # Remove TOC macros — Flare handles TOC differently
            macro.decompose()
        elif macro_name == "expand":
            _macro_expand(soup, macro)
        elif macro_name in ("panel", "section", "column"):
            # Unwrap panel/section/column — keep content only
            _unwrap_macro_body(macro)
        else:
            # Unknown macro — unwrap to keep content
            logger.debug("Unknown macro '%s', unwrapping", macro_name)
            _unwrap_macro_body(macro)


def _macro_to_callout(
    soup: BeautifulSoup, macro: Tag, css_class: str, prefix: str
) -> None:
    """Convert info/warning/tip macros to Flare callout divs."""
    body = macro.find("ac:rich-text-body")
    div = soup.new_tag("div")
    div["class"] = css_class
    div["MadCap:autonum"] = f"<b>{prefix}</b>"

    if body:
        for child in list(body.children):
            div.append(child.extract())

    macro.replace_with(div)


def _macro_to_code(soup: BeautifulSoup, macro: Tag) -> None:
    """Convert code/noformat macros to <pre><code>."""
    body = macro.find("ac:plain-text-body")
    text = body.string if body else ""

    pre = soup.new_tag("pre")
    code = soup.new_tag("code")
    code.string = text or ""
    pre.append(code)
    macro.replace_with(pre)


def _macro_expand(soup: BeautifulSoup, macro: Tag) -> None:
    """Convert expand macros — keep the body content, add title as heading."""
    title_param = macro.find("ac:parameter", attrs={"ac:name": "title"})
    body = macro.find("ac:rich-text-body")

    container = soup.new_tag("div")
    container["class"] = "expandable"

    if title_param and title_param.string:
        h3 = soup.new_tag("h3")
        h3.string = title_param.string
        container.append(h3)

    if body:
        for child in list(body.children):
            container.append(child.extract())

    macro.replace_with(container)


def _unwrap_macro_body(macro: Tag) -> None:
    """Unwrap a macro, keeping only its rich-text-body children."""
    body = macro.find("ac:rich-text-body")
    if body:
        macro.replace_with(body)
        body.unwrap()
    else:
        macro.decompose()


def _unwrap_layouts(soup: BeautifulSoup) -> None:
    """Remove Confluence layout wrappers, keeping child content."""
    for tag_name in ["ac:layout", "ac:layout-section", "ac:layout-cell"]:
        for tag in soup.find_all(tag_name):
            tag.unwrap()


def _demote_h1_to_h2(soup: BeautifulSoup) -> None:
    """Demote H1 headings to H2 (the Flare template provides its own H1)."""
    for h1 in soup.find_all("h1"):
        h1.name = "h2"


def _strip_attributes(soup: BeautifulSoup) -> None:
    """Strip Confluence-specific and style attributes from all elements."""
    KEEP_ATTRS = {"src", "href", "class", "id", "colspan", "rowspan",
                  "MadCap:autonum", "alt", "title", "width", "height"}

    for tag in soup.find_all(True):
        attrs_to_remove = []
        for attr_name in list(tag.attrs.keys()):
            # Remove Confluence-specific attributes
            if attr_name.startswith(("ac:", "ri:", "data-", "local-id")):
                attrs_to_remove.append(attr_name)
            # Remove inline styles (except on img tags where we set width)
            elif attr_name == "style" and tag.name != "img":
                attrs_to_remove.append(attr_name)
            # Remove any attribute not in the keep list
            elif attr_name not in KEEP_ATTRS:
                attrs_to_remove.append(attr_name)

        for attr_name in attrs_to_remove:
            del tag[attr_name]


def _remove_empty_paragraphs(soup: BeautifulSoup) -> None:
    """Remove empty <p> tags that are just whitespace."""
    for p in soup.find_all("p"):
        if not p.get_text(strip=True) and not p.find_all(["img", "br"]):
            p.decompose()


def _serialize(soup: BeautifulSoup) -> str:
    """Serialize the soup back to an HTML string, cleaning up whitespace."""
    html = str(soup)
    # Clean up Confluence namespace remnants
    html = re.sub(r"</?ac:[^>]+>", "", html)
    html = re.sub(r"</?ri:[^>]+>", "", html)
    # Clean up multiple blank lines
    html = re.sub(r"\n{3,}", "\n\n", html)
    return html.strip()
