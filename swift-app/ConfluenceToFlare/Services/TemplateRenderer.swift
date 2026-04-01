import Foundation

/// Renders the Flare release note HTM file from template and content.
///
/// Replaces the Jinja2 template engine with simple string substitution.
/// The template has only two variables: `{{ display_date }}` and `{{ body_content }}`.
struct TemplateRenderer {

    /// Render the release note HTM file.
    ///
    /// - Parameters:
    ///   - displayDate: Formatted date string, e.g. "January 5, 2026"
    ///   - bodyContent: Converted HTML body content from ContentConverter.
    /// - Returns: Complete HTM file content (without BOM — caller adds it).
    static func render(displayDate: String, bodyContent: String) -> String {
        var template = loadTemplate()
        template = template.replacingOccurrences(of: "{{ display_date }}", with: displayDate)
        template = template.replacingOccurrences(of: "{{ body_content }}", with: bodyContent)
        return template
    }

    /// Load the HTM template from the app bundle.
    private static func loadTemplate() -> String {
        if let url = Bundle.main.url(forResource: "release_note_template", withExtension: "htm"),
           let content = try? String(contentsOf: url, encoding: .utf8) {
            return content
        }

        // Fallback: embedded template string
        return fallbackTemplate
    }

    /// Embedded fallback template matching the Jinja2 original.
    private static let fallbackTemplate = """
    <?xml version="1.0" encoding="utf-8"?>
    <html xmlns:MadCap="http://www.madcapsoftware.com/Schemas/MadCap.xsd" style="mc-template-page: url('..\\\\..\\\\Resources\\\\MasterPages\\\\LandingTopics.flmsp');">
        <head><title></title>
            <link href="../../Resources/Stylesheets/08072023 Cognytics Release Notes.css" rel="stylesheet" />
        </head>
        <body>
            <h1>Release Notes - {{ display_date }}</h1>
            <MadCap:snippetBlock src="../../Resources/Snippets/Release Notes Image.flsnp" />
            <h2>What's new with Cognytics?</h2>
            <p>We released the latest update of Cognytics on {{ display_date }}.</p>
            {{ body_content }}
        </body>
    </html>
    """
}
