#!/usr/bin/env python3
"""Flask web application for the Confluence → Flare importer.

Provides a browser-based UI to:
1. See available Confluence release notes
2. Select which ones to import
3. Watch real-time progress via Server-Sent Events

Usage:
    cd confluence_to_flare
    python web_app.py
    # Open http://localhost:5000 in your browser
"""

import json
import logging
import time
from pathlib import Path

from flask import Flask, Response, jsonify, render_template, request, stream_with_context

from import_engine import (
    create_client,
    get_existing_releases,
    get_imported_page_ids,
    resolve_paths,
    run_import,
    validate_config,
)
from lib.date_utils import (
    format_display_date,
    format_flare_filename,
    parse_confluence_title,
)

# ── App setup ────────────────────────────────────────────

SCRIPT_DIR = Path(__file__).parent
CONFIG_PATH = SCRIPT_DIR / "config.yaml"

app = Flask(
    __name__,
    template_folder="web/templates",
    static_folder="web/static",
)

logging.basicConfig(level=logging.INFO, format="%(levelname)s: %(message)s")
logger = logging.getLogger(__name__)

# ── Simple in-memory cache for page list ─────────────────

_pages_cache = {"data": None, "timestamp": 0}
CACHE_TTL = 60  # seconds


# ── Request logging ──────────────────────────────────────

@app.after_request
def log_request(response):
    """Log every request to the terminal for debugging."""
    logger.info("%s %s → %s", request.method, request.path, response.status_code)
    return response


# ── Routes ───────────────────────────────────────────────

@app.route("/")
def index():
    """Serve the single-page UI."""
    return render_template("index.html")


@app.route("/api/config")
def check_config():
    """Validate config.yaml and return status."""
    result = validate_config(CONFIG_PATH)
    if result["valid"]:
        config = result["config"]
        return jsonify({
            "valid": True,
            "confluence_url": config["confluence"]["base_url"],
            "flare_root": config["flare_project"]["root"],
        })
    else:
        return jsonify({"valid": False, "error": result["error"]})


@app.route("/api/pages")
def list_pages():
    """Fetch available release note pages from Confluence.

    Returns a JSON list of pages with parsed dates, display dates,
    Flare filenames, and import status. Results are cached for 60s.
    """
    global _pages_cache

    force_refresh = request.args.get("refresh") == "1"
    now = time.time()

    if (not force_refresh
            and _pages_cache["data"] is not None
            and now - _pages_cache["timestamp"] < CACHE_TTL):
        return jsonify({"pages": _pages_cache["data"]})

    # Validate config
    result = validate_config(CONFIG_PATH)
    if not result["valid"]:
        return jsonify({"error": result["error"]}), 400

    config = result["config"]

    try:
        # Create client and fetch pages
        client = create_client(config)
        conf = config["confluence"]
        raw_pages = client.get_release_feature_pages(conf["production_parent_id"])

        # Resolve paths to check existing imports
        paths = resolve_paths(config, SCRIPT_DIR)
        existing = get_existing_releases(paths["release_notes_dir"])
        imported_ids = get_imported_page_ids(paths["release_notes_dir"])

        # Augment each page with parsed date info and import status
        pages = []
        for page in raw_pages:
            dt = parse_confluence_title(page["title"])
            if dt:
                filename = format_flare_filename(dt)
                pages.append({
                    "id": page["id"],
                    "title": page["title"],
                    "type": page.get("type", "other"),
                    "parsed_date": dt.strftime("%Y-%m-%d"),
                    "display_date": format_display_date(dt),
                    "filename": filename,
                    "already_imported": page["id"] in imported_ids,
                })
            else:
                # Include pages with unparseable dates too
                pages.append({
                    "id": page["id"],
                    "title": page["title"],
                    "type": page.get("type", "other"),
                    "parsed_date": None,
                    "display_date": page["title"],
                    "filename": None,
                    "already_imported": False,
                })

        # Sort by date descending (newest first), unparseable at end
        pages.sort(
            key=lambda p: p["parsed_date"] or "0000-00-00",
            reverse=True,
        )

        _pages_cache["data"] = pages
        _pages_cache["timestamp"] = now

        return jsonify({"pages": pages})

    except Exception as e:
        logger.exception("Failed to fetch pages from Confluence")
        return jsonify({"error": str(e)}), 500


@app.route("/api/import", methods=["POST"])
def start_import():
    """Start importing selected pages. Returns an SSE stream of progress events.

    Request body:
        {"page_ids": ["123", "456"], "force": false}

    Response: text/event-stream with JSON data lines.
    """
    data = request.get_json()
    if not data or not data.get("page_ids"):
        return jsonify({"error": "No page_ids provided"}), 400

    page_ids = data["page_ids"]
    force = data.get("force", False)

    # Validate config
    result = validate_config(CONFIG_PATH)
    if not result["valid"]:
        return jsonify({"error": result["error"]}), 400

    config = result["config"]

    def generate():
        try:
            for event in run_import(page_ids, config, SCRIPT_DIR, force=force):
                yield f"data: {json.dumps(event)}\n\n"
        except GeneratorExit:
            logger.warning("SSE stream closed by client during import")
        except Exception as e:
            logger.exception("Unexpected error during import")
            error_event = {"type": "error", "index": -1, "message": str(e)}
            yield f"data: {json.dumps(error_event)}\n\n"
            complete_event = {"type": "complete", "imported": 0, "skipped": 0, "errors": 1, "message": "Import failed"}
            yield f"data: {json.dumps(complete_event)}\n\n"

    # Invalidate page cache after import starts (import status will change)
    _pages_cache["data"] = None

    return Response(
        stream_with_context(generate()),
        mimetype="text/event-stream",
        headers={
            "Cache-Control": "no-cache",
            "X-Accel-Buffering": "no",
            "Connection": "keep-alive",
        },
    )


# ── Main ─────────────────────────────────────────────────

if __name__ == "__main__":
    print()
    print("  Confluence → Flare Importer")
    print("  Open http://localhost:5001 in your browser")
    print()
    app.run(debug=True, port=5001, threaded=True)
