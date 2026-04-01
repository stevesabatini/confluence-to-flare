import Foundation
import SwiftSoup

/// Converts Confluence storage format XHTML to Flare-compatible HTML.
///
/// Handles Confluence-specific elements (ac:image, ac:structured-macro,
/// ac:layout, ri:attachment, etc.) and converts them to clean HTML that
/// works in MadCap Flare topics.
struct ContentConverter {

    /// Convert Confluence storage format XHTML to Flare body HTML.
    ///
    /// - Parameters:
    ///   - xhtml: Raw XHTML from Confluence storage format.
    ///   - imageMapping: {confluence_filename: local_filename} from image handler.
    ///   - imageFolder: Date-based folder name for image paths, e.g. "05-Jan-2026".
    /// - Returns: Clean HTML string suitable for insertion into Flare topic body.
    static func convert(
        xhtml: String,
        imageMapping: [String: String],
        imageFolder: String
    ) throws -> String {
        let doc = try SwiftSoup.parseBodyFragment(xhtml)

        try convertImages(doc: doc, imageMapping: imageMapping, imageFolder: imageFolder)
        try convertMacros(doc: doc)
        try unwrapLayouts(doc: doc)
        try demoteH1ToH2(doc: doc)
        try stripAttributes(doc: doc)
        try removeEmptyParagraphs(doc: doc)

        return try serialize(doc: doc)
    }

    // MARK: - Image Conversion

    /// Replace ac:image elements with standard <img> tags.
    private static func convertImages(
        doc: Document,
        imageMapping: [String: String],
        imageFolder: String
    ) throws {
        for acImage in try doc.getElementsByTag("ac:image").array() {
            if let riAttachment = try acImage.getElementsByTag("ri:attachment").first() {
                let confluenceName = try riAttachment.attr("ri:filename")
                let localName = imageMapping[confluenceName] ?? confluenceName
                let src = "../../Resources/From Confluence/Release Notes/\(imageFolder)/\(localName)"

                let imgTag = try doc.createElement("img")
                try imgTag.attr("src", src)

                // Preserve width from ac:image
                let width = try acImage.attr("ac:width")
                if !width.isEmpty {
                    try imgTag.attr("style", "width: \(width)px;")
                }

                try acImage.replaceWith(imgTag)
            } else if let riURL = try acImage.getElementsByTag("ri:url").first() {
                let url = try riURL.attr("ri:value")
                let imgTag = try doc.createElement("img")
                try imgTag.attr("src", url)
                try acImage.replaceWith(imgTag)
            } else {
                try acImage.remove()
            }
        }
    }

    // MARK: - Macro Conversion

    /// Convert ac:structured-macro elements to Flare equivalents.
    private static func convertMacros(doc: Document) throws {
        for macro in try doc.getElementsByTag("ac:structured-macro").array() {
            let macroName = try macro.attr("ac:name")

            switch macroName {
            case "info", "note":
                try macroToCallout(doc: doc, macro: macro, cssClass: "note", prefix: "Note: ")
            case "warning":
                try macroToCallout(doc: doc, macro: macro, cssClass: "warning", prefix: "Warning: ")
            case "tip":
                try macroToCallout(doc: doc, macro: macro, cssClass: "tip", prefix: "Tip: ")
            case "code", "noformat":
                try macroToCode(doc: doc, macro: macro)
            case "toc":
                try macro.remove()
            case "expand":
                try macroExpand(doc: doc, macro: macro)
            case "panel", "section", "column":
                try unwrapMacroBody(macro: macro)
            default:
                try unwrapMacroBody(macro: macro)
            }
        }
    }

    /// Convert info/warning/tip macros to Flare callout divs.
    private static func macroToCallout(
        doc: Document,
        macro: Element,
        cssClass: String,
        prefix: String
    ) throws {
        let body = try macro.getElementsByTag("ac:rich-text-body").first()
        let div = try doc.createElement("div")
        try div.attr("class", cssClass)
        try div.attr("MadCap:autonum", "<b>\(prefix)</b>")

        if let body {
            for child in body.getChildNodes().array() {
                try div.appendChild(child)
            }
        }

        try macro.replaceWith(div)
    }

    /// Convert code/noformat macros to <pre><code>.
    private static func macroToCode(doc: Document, macro: Element) throws {
        let body = try macro.getElementsByTag("ac:plain-text-body").first()
        let text = body != nil ? (try body!.text()) : ""

        let pre = try doc.createElement("pre")
        let code = try doc.createElement("code")
        try code.text(text)
        try pre.appendChild(code)
        try macro.replaceWith(pre)
    }

    /// Convert expand macros — keep body content, add title as heading.
    private static func macroExpand(doc: Document, macro: Element) throws {
        let container = try doc.createElement("div")
        try container.attr("class", "expandable")

        // Look for title parameter
        for param in try macro.getElementsByTag("ac:parameter").array() {
            let paramName = try param.attr("ac:name")
            if paramName == "title" {
                let titleText = try param.text()
                if !titleText.isEmpty {
                    let h3 = try doc.createElement("h3")
                    try h3.text(titleText)
                    try container.appendChild(h3)
                }
                break
            }
        }

        // Move body content
        if let body = try macro.getElementsByTag("ac:rich-text-body").first() {
            for child in body.getChildNodes().array() {
                try container.appendChild(child)
            }
        }

        try macro.replaceWith(container)
    }

    /// Unwrap a macro, keeping only its rich-text-body children.
    private static func unwrapMacroBody(macro: Element) throws {
        if let body = try macro.getElementsByTag("ac:rich-text-body").first() {
            // Move body's children to before the macro, then remove macro
            let parent = macro.parent()
            if let parent {
                let children = body.getChildNodes().array()
                let macroIndex = macro.siblingIndex()
                for (i, child) in children.enumerated() {
                    try parent.insertChildren(macroIndex + i, child)
                }
            }
            try macro.remove()
        } else {
            try macro.remove()
        }
    }

    // MARK: - Layout Unwrapping

    /// Remove Confluence layout wrappers, keeping child content.
    private static func unwrapLayouts(doc: Document) throws {
        for tagName in ["ac:layout", "ac:layout-section", "ac:layout-cell"] {
            // Process iteratively since unwrapping changes the tree
            while true {
                guard let tag = try doc.getElementsByTag(tagName).first() else { break }
                // Move children out, then remove the wrapper
                let parent = tag.parent()
                if let parent {
                    let tagIndex = tag.siblingIndex()
                    let children = tag.getChildNodes().array()
                    for (i, child) in children.enumerated() {
                        try parent.insertChildren(tagIndex + i, child)
                    }
                }
                try tag.remove()
            }
        }
    }

    // MARK: - H1 Demotion

    /// Demote H1 headings to H2 (the Flare template provides its own H1).
    private static func demoteH1ToH2(doc: Document) throws {
        for h1 in try doc.getElementsByTag("h1").array() {
            try h1.tagName("h2")
        }
    }

    // MARK: - Attribute Stripping

    private static let keepAttributes: Set<String> = [
        "src", "href", "class", "id", "colspan", "rowspan",
        "MadCap:autonum", "alt", "title", "width", "height",
    ]

    /// Strip Confluence-specific and style attributes from all elements.
    private static func stripAttributes(doc: Document) throws {
        for tag in try doc.getAllElements().array() {
            let attributes = tag.getAttributes()
            guard let attributes else { continue }

            var toRemove: [String] = []
            for attr in attributes {
                let key = attr.getKey()
                if key.hasPrefix("ac:") || key.hasPrefix("ri:") ||
                   key.hasPrefix("data-") || key == "local-id" {
                    toRemove.append(key)
                } else if key == "style" && tag.tagName() != "img" {
                    toRemove.append(key)
                } else if !keepAttributes.contains(key) {
                    toRemove.append(key)
                }
            }

            for key in toRemove {
                try tag.removeAttr(key)
            }
        }
    }

    // MARK: - Empty Paragraph Removal

    /// Remove empty <p> tags that are just whitespace.
    private static func removeEmptyParagraphs(doc: Document) throws {
        for p in try doc.getElementsByTag("p").array() {
            let text = try p.text().trimmingCharacters(in: .whitespacesAndNewlines)
            let hasImgOrBr = try !p.getElementsByTag("img").isEmpty() || !p.getElementsByTag("br").isEmpty()
            if text.isEmpty && !hasImgOrBr {
                try p.remove()
            }
        }
    }

    // MARK: - Serialization

    /// Serialize the document back to an HTML string, cleaning up namespace remnants.
    private static func serialize(doc: Document) throws -> String {
        var html = try doc.body()?.html() ?? ""

        // Restore MadCap attribute casing (SwiftSoup lowercases it)
        html = html.replacingOccurrences(of: "madcap:autonum", with: "MadCap:autonum")

        // Clean up Confluence namespace remnants
        html = html.replacingOccurrences(
            of: "</?ac:[^>]+>",
            with: "",
            options: .regularExpression
        )
        html = html.replacingOccurrences(
            of: "</?ri:[^>]+>",
            with: "",
            options: .regularExpression
        )

        // Clean up multiple blank lines
        html = html.replacingOccurrences(
            of: "\n{3,}",
            with: "\n\n",
            options: .regularExpression
        )

        return html.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
