import Foundation
import os

/// Updates Flare project files (Overview page and Mini-TOC) when new
/// release notes are imported.
///
/// Uses string-based insertion for both the Overview HTML page and the
/// Mini-TOC XML file to preserve exact formatting and MadCap namespaces.
struct FlareUpdater {
    private static let logger = Logger(subsystem: "ConfluenceToFlare", category: "FlareUpdater")

    // MARK: - Overview Page Update

    /// Insert a new release note link in date order on the Overview page.
    ///
    /// Adds a `<li><p><a href="...">Release: Month DD, YYYY</a></p></li>`
    /// in the correct position within the `<ul>`, maintaining newest-first ordering.
    ///
    /// Uses string-based insertion to preserve exact HTML/XML formatting
    /// (avoids SwiftSoup's HTML5 normalization which corrupts MadCap Flare XML).
    static func updateOverviewPage(
        overviewPath: URL,
        filename: String,
        linkText: String,
        releaseDate: Date
    ) throws {
        var raw = try readWithBOM(url: overviewPath)

        // Build the new list item as a plain string
        let escapedFilename = escapeXMLAttribute(filename)
        let escapedText = linkText
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
        let newEntry = "<li><p><a href=\"\(escapedFilename)\">\(escapedText)</a></p></li>"

        // Find existing <li> entries by scanning for href patterns
        let hrefPattern = try NSRegularExpression(
            pattern: #"<li>\s*<p>\s*<a\s+href="([^"]+)">"#,
            options: []
        )
        let matches = hrefPattern.matches(in: raw, range: NSRange(raw.startIndex..., in: raw))

        // Collect existing entries with their dates and positions
        var insertionIndex: String.Index?

        for match in matches {
            guard let hrefRange = Range(match.range(at: 1), in: raw) else { continue }
            let href = String(raw[hrefRange])
            guard let existingDate = DateParser.parseDateFromFilename(href) else { continue }
            if existingDate < releaseDate {
                // Insert before this <li>
                guard let liRange = Range(match.range(at: 0), in: raw) else { continue }
                insertionIndex = liRange.lowerBound
                break
            }
        }

        if let insertionIndex {
            // Determine indentation from the line we're inserting before
            let lineStart = raw[raw.startIndex..<insertionIndex].lastIndex(of: "\n")
                .map { raw.index(after: $0) } ?? insertionIndex
            let indent = String(raw[lineStart..<insertionIndex])
            raw.insert(contentsOf: "\(newEntry)\n\(indent)", at: insertionIndex)
        } else {
            // No existing entry with an older date found — append before </ul>
            if let ulCloseRange = raw.range(of: "</ul>") {
                let lineStart = raw[raw.startIndex..<ulCloseRange.lowerBound].lastIndex(of: "\n")
                    .map { raw.index(after: $0) } ?? ulCloseRange.lowerBound
                let indent = String(raw[lineStart..<ulCloseRange.lowerBound])
                // Use the same indent as </ul> plus extra for the child
                let childIndent = indent + "    "
                raw.insert(contentsOf: "\(childIndent)\(newEntry)\n", at: ulCloseRange.lowerBound)
            } else {
                logger.error("Could not find <ul> or </ul> in overview page")
                return
            }
        }

        try BOMWriter.write(raw, to: overviewPath)
        logger.info("Updated overview page with link to \(filename)")
    }

    // MARK: - Mini-TOC Update

    /// Insert a new TocEntry in date order in the Mini-TOC.
    ///
    /// Uses string-based insertion to preserve exact XML formatting.
    static func updateMiniToc(
        tocPath: URL,
        filename: String,
        tocTitle: String,
        releaseDate: Date
    ) throws {
        var raw = try readWithBOM(url: tocPath)
        let link = "/Content/E_Landing Topics/Release Notes/\(filename)"
        let newEntry = "<TocEntry Title=\"\(escapeXMLAttribute(tocTitle))\" Link=\"\(escapeXMLAttribute(link))\" />"

        // Find the Release Notes parent TocEntry
        guard let rnRange = raw.range(of: "Title=\"Release Notes\"") else {
            logger.error("Could not find 'Release Notes' TocEntry in Mini-TOC")
            return
        }

        // Find all child TocEntry elements within the Release Notes parent
        // We need to find the right insertion point

        // Get the substring after the Release Notes entry opening
        let afterRN = raw[rnRange.upperBound...]

        // Collect positions of direct child TocEntry elements
        var childPositions: [(range: Range<String.Index>, link: String, date: Date?)] = []
        var searchStart = afterRN.startIndex

        // Find a reasonable end boundary (the closing </TocEntry> for Release Notes)
        // We look for TocEntry elements and their Link attributes
        let tocEntryPattern = #/TocEntry\s+Title="[^"]*"\s+Link="([^"]*)"/#
        let closingPattern = #/<\/TocEntry>/#

        // Scan for child TocEntry elements
        var depth = 0
        var currentIndex = afterRN.startIndex
        while currentIndex < afterRN.endIndex {
            let remaining = String(afterRN[currentIndex...])

            // Check for opening TocEntry
            if remaining.hasPrefix("<TocEntry") {
                if depth == 0 {
                    // This is a direct child
                    if let match = remaining.firstMatch(of: tocEntryPattern) {
                        let linkValue = String(match.output.1)
                        let date = DateParser.parseDateFromFilename(linkValue)
                        let posInFull = raw.index(currentIndex, offsetBy: 0)
                        childPositions.append((range: posInFull..<posInFull, link: linkValue, date: date))
                    }
                }

                // Check if self-closing
                if let closeAngle = remaining.firstIndex(of: ">") {
                    let beforeClose = remaining[remaining.startIndex..<closeAngle]
                    if beforeClose.hasSuffix("/") {
                        // Self-closing, don't increase depth
                    } else {
                        depth += 1
                    }
                    currentIndex = afterRN.index(currentIndex, offsetBy: remaining.distance(from: remaining.startIndex, to: closeAngle) + 1)
                    continue
                }
            }

            // Check for closing TocEntry
            if remaining.hasPrefix("</TocEntry>") {
                if depth == 0 {
                    // This is the closing tag of the Release Notes parent — stop scanning
                    break
                }
                depth -= 1
                currentIndex = afterRN.index(currentIndex, offsetBy: "</TocEntry>".count)
                continue
            }

            currentIndex = afterRN.index(after: currentIndex)
        }

        // Find the correct insertion position
        var insertionIndex: String.Index?
        for child in childPositions {
            if child.link.isEmpty {
                // Entry with no link (e.g. Archive) — insert before it
                insertionIndex = child.range.lowerBound
                break
            }
            if let existingDate = child.date, existingDate < releaseDate {
                insertionIndex = child.range.lowerBound
                break
            }
        }

        // Determine indentation
        let indent = "    "

        if let insertionIndex {
            // Insert before the found position
            raw.insert(contentsOf: "\(newEntry)\n\(indent)", at: insertionIndex)
        } else {
            // Insert at the end of the Release Notes children
            // Find the closing </TocEntry> for the Release Notes parent
            if let closingRange = raw.range(of: "</TocEntry>", range: rnRange.upperBound..<raw.endIndex) {
                raw.insert(contentsOf: "\(indent)\(newEntry)\n", at: closingRange.lowerBound)
            }
        }

        try BOMWriter.write(raw, to: tocPath)
        logger.info("Updated Mini-TOC with entry for \(filename)")
    }

    // MARK: - Helpers

    private static func readWithBOM(url: URL) throws -> String {
        let data = try Data(contentsOf: url)
        // Handle UTF-8 BOM (EF BB BF)
        if data.starts(with: [0xEF, 0xBB, 0xBF]) {
            return String(data: data.dropFirst(3), encoding: .utf8) ?? ""
        }
        return String(data: data, encoding: .utf8) ?? ""
    }

    private static func escapeXMLAttribute(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }
}
