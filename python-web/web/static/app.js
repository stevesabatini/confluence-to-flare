/**
 * Confluence -> Flare Importer -- Frontend Logic
 *
 * Handles page listing, selection, and real-time import progress via SSE.
 */

// -- State -------------------------------------------------------

let pages = [];           // Page data from /api/pages
let selectedIds = new Set(); // Currently selected page IDs

// -- Initialization ----------------------------------------------

document.addEventListener("DOMContentLoaded", init);

async function init() {
    console.log("[init] Starting...");
    setLoadingMessage("Checking configuration...");
    showState("loading");

    try {
        console.log("[init] Fetching /api/config...");
        const configResp = await fetch("/api/config");
        const configData = await configResp.json();
        console.log("[init] Config response:", configData);

        if (!configData.valid) {
            document.getElementById("config-error-message").textContent = configData.error;
            showState("config-error");
            return;
        }

        console.log("[init] Config valid, loading pages...");
        await loadPages(false);
    } catch (err) {
        console.error("[init] Error:", err);
        document.getElementById("config-error-message").textContent =
            "Could not connect to the server: " + err.message;
        showState("config-error");
    }
}

// -- State Management --------------------------------------------

function showState(stateId) {
    document.querySelectorAll(".state").forEach(function(el) {
        el.style.display = "none";
    });
    var el = document.getElementById(stateId);
    if (el) el.style.display = "block";
}

function setLoadingMessage(msg) {
    var el = document.getElementById("loading-message");
    if (el) el.textContent = msg;
}

// -- Page Loading ------------------------------------------------

async function loadPages(forceRefresh) {
    setLoadingMessage("Fetching release notes from Confluence...");
    showState("loading");

    try {
        var url = forceRefresh ? "/api/pages?refresh=1" : "/api/pages";
        console.log("[loadPages] Fetching", url);

        // Use AbortController for a 60-second timeout
        var controller = new AbortController();
        var timeoutId = setTimeout(function() { controller.abort(); }, 60000);

        var resp = await fetch(url, { signal: controller.signal });
        clearTimeout(timeoutId);

        var data = await resp.json();
        console.log("[loadPages] Got response:", data.pages ? data.pages.length + " pages" : "error");

        if (data.error) {
            document.getElementById("config-error-message").textContent = data.error;
            showState("config-error");
            return;
        }

        pages = data.pages;
        selectedIds.clear();
        renderPageList();
        showState("page-selection");
    } catch (err) {
        console.error("[loadPages] Error:", err);
        var msg = err.name === "AbortError"
            ? "Request timed out. Confluence may be slow or unreachable. Try again with the Refresh button."
            : "Failed to fetch pages: " + err.message;
        document.getElementById("config-error-message").textContent = msg;
        showState("config-error");
    }
}

function refreshPages() {
    loadPages(true);
}

// -- Page List Rendering -----------------------------------------

function renderPageList() {
    var list = document.getElementById("page-list");
    var force = document.getElementById("force-reimport").checked;

    list.innerHTML = "";

    if (pages.length === 0) {
        list.innerHTML = '<div class="empty-state">No release notes found in Confluence.</div>';
        updateCounts();
        return;
    }

    pages.forEach(function(page) {
        var row = document.createElement("div");
        row.className = "page-row" + (page.already_imported && !force ? " imported" : "");
        row.dataset.pageId = page.id;

        var checkbox = document.createElement("input");
        checkbox.type = "checkbox";
        checkbox.className = "page-checkbox";
        checkbox.dataset.pageId = page.id;
        checkbox.checked = selectedIds.has(page.id);
        checkbox.disabled = page.already_imported && !force;
        checkbox.addEventListener("change", function() {
            onCheckboxChange(page.id, checkbox.checked);
        });

        var info = document.createElement("div");
        info.className = "page-info";

        var topLine = document.createElement("div");
        topLine.className = "page-top-line";

        var dateSpan = document.createElement("span");
        dateSpan.className = "page-date";
        dateSpan.textContent = page.display_date;

        var badges = document.createElement("span");
        badges.className = "page-badges";

        var typeBadge = document.createElement("span");
        typeBadge.className = "badge badge-" + page.type;
        typeBadge.textContent = page.type;
        badges.appendChild(typeBadge);

        if (page.already_imported) {
            var importedBadge = document.createElement("span");
            importedBadge.className = "badge badge-imported";
            importedBadge.textContent = "IMPORTED";
            badges.appendChild(importedBadge);
        }

        topLine.appendChild(dateSpan);
        topLine.appendChild(badges);

        var titleLine = document.createElement("div");
        titleLine.className = "page-title";
        titleLine.textContent = page.title;

        info.appendChild(topLine);
        info.appendChild(titleLine);

        row.appendChild(checkbox);
        row.appendChild(info);
        list.appendChild(row);
    });

    updateCounts();
}

// -- Selection Logic ---------------------------------------------

function onCheckboxChange(pageId, checked) {
    if (checked) {
        selectedIds.add(pageId);
    } else {
        selectedIds.delete(pageId);
    }
    updateCounts();
    updateSelectAll();
}

function toggleSelectAll() {
    var selectAll = document.getElementById("select-all").checked;
    var force = document.getElementById("force-reimport").checked;

    selectedIds.clear();

    pages.forEach(function(page) {
        var eligible = !page.already_imported || force;
        if (selectAll && eligible) {
            selectedIds.add(page.id);
        }
    });

    // Update all checkboxes
    document.querySelectorAll(".page-checkbox").forEach(function(cb) {
        var pageId = cb.dataset.pageId;
        var page = pages.find(function(p) { return p.id === pageId; });
        var eligible = page && (!page.already_imported || force);
        cb.checked = selectAll && eligible;
    });

    updateCounts();
}

function updateSelectAll() {
    var force = document.getElementById("force-reimport").checked;
    var eligiblePages = pages.filter(function(p) { return !p.already_imported || force; });
    var allSelected = eligiblePages.length > 0 && eligiblePages.every(function(p) { return selectedIds.has(p.id); });
    document.getElementById("select-all").checked = allSelected;
}

function onForceChange() {
    // Re-render to update dimming and checkbox disabled state
    renderPageList();
}

function updateCounts() {
    var count = selectedIds.size;
    document.getElementById("selected-count").textContent = count;
    document.getElementById("btn-import").disabled = count === 0;
    document.getElementById("page-count").textContent =
        pages.length + " release note(s) in Confluence";
}

// -- Import ------------------------------------------------------

async function startImport() {
    var pageIds = Array.from(selectedIds);
    var force = document.getElementById("force-reimport").checked;

    if (pageIds.length === 0) return;

    // Switch to progress view
    showState("import-progress");
    document.getElementById("progress-list").innerHTML = "";
    document.getElementById("import-complete").style.display = "none";
    document.getElementById("progress-bar").style.width = "0%";
    document.getElementById("progress-title").textContent = "Starting import...";
    document.getElementById("progress-text").textContent = "";

    try {
        var response = await fetch("/api/import", {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({ page_ids: pageIds, force: force }),
        });

        var reader = response.body.getReader();
        var decoder = new TextDecoder();
        var buffer = "";

        while (true) {
            var result = await reader.read();
            if (result.done) break;

            buffer += decoder.decode(result.value, { stream: true });

            // Parse SSE data lines from buffer
            var parts = buffer.split("\n\n");
            buffer = parts.pop(); // Keep incomplete last chunk

            for (var i = 0; i < parts.length; i++) {
                var lines = parts[i].split("\n");
                for (var j = 0; j < lines.length; j++) {
                    if (lines[j].startsWith("data: ")) {
                        try {
                            var event = JSON.parse(lines[j].substring(6));
                            handleProgressEvent(event);
                        } catch (e) {
                            console.error("Failed to parse SSE event:", lines[j], e);
                        }
                    }
                }
            }
        }

        // Process any remaining buffer
        if (buffer.trim()) {
            var remainingLines = buffer.split("\n");
            for (var k = 0; k < remainingLines.length; k++) {
                if (remainingLines[k].startsWith("data: ")) {
                    try {
                        var evt = JSON.parse(remainingLines[k].substring(6));
                        handleProgressEvent(evt);
                    } catch (e) {
                        console.error("Failed to parse remaining SSE:", remainingLines[k], e);
                    }
                }
            }
        }
    } catch (err) {
        console.error("[startImport] Error:", err);
        handleProgressEvent({
            type: "error",
            index: -1,
            message: "Connection lost: " + err.message,
        });
        handleProgressEvent({
            type: "complete",
            imported: 0,
            skipped: 0,
            errors: 1,
            message: "Import failed due to connection error",
        });
    }
}

// -- Progress Event Handler --------------------------------------

var currentTotal = 0;
var completedPages = 0;

function handleProgressEvent(event) {
    var list = document.getElementById("progress-list");

    switch (event.type) {
        case "start":
            currentTotal = event.total;
            completedPages = 0;
            document.getElementById("progress-title").textContent =
                "Importing " + event.total + " release note(s)...";
            document.getElementById("progress-text").textContent = "0 of " + event.total;
            break;

        case "page_start": {
            var card = document.createElement("div");
            card.className = "progress-card";
            card.id = "progress-page-" + event.index;

            var header = document.createElement("div");
            header.className = "progress-card-header";
            header.innerHTML = '<span class="icon icon-active"></span> ' + escapeHtml(event.title);

            var steps = document.createElement("div");
            steps.className = "progress-steps";
            steps.id = "progress-steps-" + event.index;

            card.appendChild(header);
            card.appendChild(steps);
            list.appendChild(card);

            // Auto-scroll to the new card
            card.scrollIntoView({ behavior: "smooth", block: "nearest" });
            break;
        }

        case "step": {
            var stepsEl = document.getElementById("progress-steps-" + event.index);
            if (!stepsEl) break;

            // Replace "in progress" steps with completed versions
            var existing = stepsEl.querySelector('[data-step="' + event.step + '"]');
            if (existing) {
                existing.remove();
            }

            var step = document.createElement("div");
            step.className = "progress-step";
            step.dataset.step = event.step;

            var isDone = event.step.endsWith("_done");
            if (isDone) {
                step.innerHTML = '<span class="icon icon-done"></span> ' + escapeHtml(event.message);
                // Remove the corresponding "in progress" step
                var baseStep = event.step.replace("_done", "");
                var inProgress = stepsEl.querySelector('[data-step="' + baseStep + '"]');
                if (inProgress) inProgress.remove();
            } else {
                step.innerHTML = '<span class="icon icon-active"></span> ' + escapeHtml(event.message);
            }

            stepsEl.appendChild(step);
            break;
        }

        case "skip": {
            var skipCard = document.createElement("div");
            skipCard.className = "progress-card skipped";
            skipCard.innerHTML = '<div class="progress-card-header">' +
                '<span class="icon icon-skip"></span> ' + escapeHtml(event.message) +
                '</div>';
            list.appendChild(skipCard);
            completedPages++;
            updateProgressBarDisplay();
            break;
        }

        case "page_done": {
            var doneCard = document.getElementById("progress-page-" + event.index);
            if (doneCard) {
                var doneHeader = doneCard.querySelector(".progress-card-header");
                doneHeader.innerHTML = '<span class="icon icon-done"></span> ' + escapeHtml(event.message);
                doneCard.classList.add("done");
            }
            completedPages++;
            updateProgressBarDisplay();
            break;
        }

        case "error": {
            if (event.index >= 0) {
                var errCard = document.getElementById("progress-page-" + event.index);
                if (errCard) {
                    var errSteps = errCard.querySelector(".progress-steps");
                    var errStep = document.createElement("div");
                    errStep.className = "progress-step error";
                    errStep.innerHTML = '<span class="icon icon-error"></span> ' + escapeHtml(event.message);
                    errSteps.appendChild(errStep);
                    errCard.classList.add("has-error");

                    var errHeader = errCard.querySelector(".progress-card-header");
                    errHeader.innerHTML = '<span class="icon icon-error"></span> Error: ' + escapeHtml(event.message);
                }
            } else {
                var errorDiv = document.createElement("div");
                errorDiv.className = "progress-card has-error";
                errorDiv.innerHTML = '<div class="progress-card-header">' +
                    '<span class="icon icon-error"></span> ' + escapeHtml(event.message) +
                    '</div>';
                list.appendChild(errorDiv);
            }
            completedPages++;
            updateProgressBarDisplay();
            break;
        }

        case "complete": {
            document.getElementById("progress-title").textContent = "Import Complete";
            document.getElementById("progress-bar").style.width = "100%";
            document.getElementById("progress-text").textContent = "";

            var summary = document.getElementById("complete-summary");
            var hasErrors = event.errors > 0;
            summary.className = "alert " + (hasErrors ? "alert-warning" : "alert-success");

            var msgParts = [];
            if (event.imported > 0) msgParts.push(event.imported + " imported");
            if (event.skipped > 0) msgParts.push(event.skipped + " skipped");
            if (event.errors > 0) msgParts.push(event.errors + " error(s)");
            summary.textContent = msgParts.join(", ") || "Nothing to import";

            document.getElementById("import-complete").style.display = "block";
            break;
        }
    }
}

function updateProgressBarDisplay() {
    if (currentTotal > 0) {
        var pct = Math.round((completedPages / currentTotal) * 100);
        document.getElementById("progress-bar").style.width = pct + "%";
        document.getElementById("progress-text").textContent =
            completedPages + " of " + currentTotal;
    }
}

// -- Navigation --------------------------------------------------

function backToList() {
    loadPages(true); // Refresh to pick up newly imported files
}

// -- Utilities ---------------------------------------------------

function escapeHtml(text) {
    var div = document.createElement("div");
    div.textContent = text;
    return div.innerHTML;
}
