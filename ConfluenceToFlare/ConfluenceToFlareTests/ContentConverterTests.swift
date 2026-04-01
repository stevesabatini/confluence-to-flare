import Testing
import Foundation
@testable import ConfluenceToFlare

@Suite("ContentConverter Tests")
struct ContentConverterTests {

    // MARK: - Image Conversion

    @Test("Convert ac:image with ri:attachment to img tag")
    func convertImageAttachment() throws {
        let xhtml = """
        <p><ac:image ac:width="600"><ri:attachment ri:filename="screenshot.png" /></ac:image></p>
        """
        let result = try ContentConverter.convert(
            xhtml: xhtml,
            imageMapping: ["screenshot.png": "screenshot.png"],
            imageFolder: "05-Jan-2026"
        )
        #expect(result.contains("<img"))
        #expect(result.contains("../../Resources/From Confluence/Release Notes/05-Jan-2026/screenshot.png"))
        #expect(!result.contains("ac:image"))
    }

    @Test("Convert ac:image with width to img with style")
    func convertImageWithWidth() throws {
        let xhtml = """
        <p><ac:image ac:width="400"><ri:attachment ri:filename="test.png" /></ac:image></p>
        """
        let result = try ContentConverter.convert(
            xhtml: xhtml,
            imageMapping: ["test.png": "test.png"],
            imageFolder: "01-Feb-2026"
        )
        #expect(result.contains("width: 400px"))
    }

    @Test("Convert ac:image with ri:url to img with external src")
    func convertImageURL() throws {
        let xhtml = """
        <p><ac:image><ri:url ri:value="https://example.com/photo.jpg" /></ac:image></p>
        """
        let result = try ContentConverter.convert(xhtml: xhtml, imageMapping: [:], imageFolder: "")
        #expect(result.contains("<img"))
        #expect(result.contains("https://example.com/photo.jpg"))
    }

    @Test("Image mapping renames file correctly")
    func imageRenaming() throws {
        let xhtml = """
        <p><ac:image><ri:attachment ri:filename="image (1).png" /></ac:image></p>
        """
        let result = try ContentConverter.convert(
            xhtml: xhtml,
            imageMapping: ["image (1).png": "image_1.png"],
            imageFolder: "09-Mar-2026"
        )
        #expect(result.contains("image_1.png"))
        #expect(!result.contains("image (1).png"))
    }

    // MARK: - Macro Conversion

    @Test("Convert info macro to note callout div")
    func convertInfoMacro() throws {
        let xhtml = """
        <ac:structured-macro ac:name="info"><ac:rich-text-body><p>Important info here</p></ac:rich-text-body></ac:structured-macro>
        """
        let result = try ContentConverter.convert(xhtml: xhtml, imageMapping: [:], imageFolder: "")
        #expect(result.contains("class=\"note\""))
        #expect(result.contains("Important info here"))
        #expect(!result.contains("ac:structured-macro"))
    }

    @Test("Convert warning macro to warning callout div")
    func convertWarningMacro() throws {
        let xhtml = """
        <ac:structured-macro ac:name="warning"><ac:rich-text-body><p>Be careful!</p></ac:rich-text-body></ac:structured-macro>
        """
        let result = try ContentConverter.convert(xhtml: xhtml, imageMapping: [:], imageFolder: "")
        #expect(result.contains("class=\"warning\""))
        #expect(result.contains("Be careful!"))
    }

    @Test("Convert tip macro to tip callout div")
    func convertTipMacro() throws {
        let xhtml = """
        <ac:structured-macro ac:name="tip"><ac:rich-text-body><p>Pro tip here</p></ac:rich-text-body></ac:structured-macro>
        """
        let result = try ContentConverter.convert(xhtml: xhtml, imageMapping: [:], imageFolder: "")
        #expect(result.contains("class=\"tip\""))
        #expect(result.contains("Pro tip here"))
    }

    @Test("Convert code macro to pre/code")
    func convertCodeMacro() throws {
        let xhtml = """
        <ac:structured-macro ac:name="code"><ac:plain-text-body>console.log("hello")</ac:plain-text-body></ac:structured-macro>
        """
        let result = try ContentConverter.convert(xhtml: xhtml, imageMapping: [:], imageFolder: "")
        #expect(result.contains("<pre>"))
        #expect(result.contains("<code>"))
    }

    @Test("Remove TOC macro")
    func removeTocMacro() throws {
        let xhtml = """
        <p>Before</p><ac:structured-macro ac:name="toc"></ac:structured-macro><p>After</p>
        """
        let result = try ContentConverter.convert(xhtml: xhtml, imageMapping: [:], imageFolder: "")
        #expect(!result.contains("toc"))
        #expect(result.contains("Before"))
        #expect(result.contains("After"))
    }

    @Test("Convert expand macro preserves title and body")
    func convertExpandMacro() throws {
        let xhtml = """
        <ac:structured-macro ac:name="expand"><ac:parameter ac:name="title">Click to expand</ac:parameter><ac:rich-text-body><p>Hidden content</p></ac:rich-text-body></ac:structured-macro>
        """
        let result = try ContentConverter.convert(xhtml: xhtml, imageMapping: [:], imageFolder: "")
        #expect(result.contains("expandable"))
        #expect(result.contains("Click to expand"))
        #expect(result.contains("Hidden content"))
    }

    // MARK: - Layout Unwrapping

    @Test("Unwrap layout elements keeping content")
    func unwrapLayouts() throws {
        let xhtml = """
        <ac:layout><ac:layout-section><ac:layout-cell><p>Content here</p></ac:layout-cell></ac:layout-section></ac:layout>
        """
        let result = try ContentConverter.convert(xhtml: xhtml, imageMapping: [:], imageFolder: "")
        #expect(result.contains("Content here"))
        #expect(!result.contains("ac:layout"))
    }

    // MARK: - H1 Demotion

    @Test("Demote h1 to h2")
    func demoteH1() throws {
        let xhtml = "<h1>My Heading</h1><p>Content</p>"
        let result = try ContentConverter.convert(xhtml: xhtml, imageMapping: [:], imageFolder: "")
        #expect(result.contains("<h2>"))
        #expect(!result.contains("<h1>"))
        #expect(result.contains("My Heading"))
    }

    // MARK: - Attribute Stripping

    @Test("Strip Confluence-specific attributes")
    func stripAttributes() throws {
        let xhtml = """
        <p data-some="value" local-id="abc123">Text</p>
        """
        let result = try ContentConverter.convert(xhtml: xhtml, imageMapping: [:], imageFolder: "")
        #expect(!result.contains("data-some"))
        #expect(!result.contains("local-id"))
        #expect(result.contains("Text"))
    }

    @Test("Preserve allowed attributes: href, class, id, colspan, rowspan")
    func preserveAllowedAttributes() throws {
        let xhtml = """
        <table><tr><td colspan="2" rowspan="3">Cell</td></tr></table>
        """
        let result = try ContentConverter.convert(xhtml: xhtml, imageMapping: [:], imageFolder: "")
        #expect(result.contains("colspan=\"2\""))
        #expect(result.contains("rowspan=\"3\""))
    }

    @Test("Keep style on img tags, strip on other elements")
    func styleOnImgOnly() throws {
        let xhtml = """
        <p style="color: red;">Text</p>
        <p><ac:image ac:width="300"><ri:attachment ri:filename="pic.png" /></ac:image></p>
        """
        let result = try ContentConverter.convert(
            xhtml: xhtml,
            imageMapping: ["pic.png": "pic.png"],
            imageFolder: "01-Jan-2026"
        )
        // style should be stripped from the <p> but kept on the <img>
        #expect(result.contains("style=\"width: 300px;\""))
        #expect(!result.contains("color: red"))
    }

    // MARK: - Empty Paragraph Removal

    @Test("Remove empty paragraphs")
    func removeEmptyParagraphs() throws {
        let xhtml = "<p>   </p><p>Real content</p><p></p>"
        let result = try ContentConverter.convert(xhtml: xhtml, imageMapping: [:], imageFolder: "")
        #expect(result.contains("Real content"))
    }

    @Test("Preserve paragraphs with images inside")
    func preserveParagraphsWithImages() throws {
        let xhtml = """
        <p><ac:image><ri:attachment ri:filename="test.png" /></ac:image></p>
        """
        let result = try ContentConverter.convert(
            xhtml: xhtml,
            imageMapping: ["test.png": "test.png"],
            imageFolder: "01-Jan-2026"
        )
        #expect(result.contains("<img"))
    }

    // MARK: - Namespace Cleanup

    @Test("Clean up leftover ac: and ri: tags in output")
    func cleanupNamespaceTags() throws {
        let xhtml = "<p>Content</p>"
        let result = try ContentConverter.convert(xhtml: xhtml, imageMapping: [:], imageFolder: "")
        #expect(!result.contains("<ac:"))
        #expect(!result.contains("<ri:"))
    }

    // MARK: - MadCap Attribute Preservation (SERIALIZATION CRITICAL)

    @Test("MadCap:autonum attribute preserved with correct casing")
    func madcapAutonumCasing() throws {
        let xhtml = """
        <ac:structured-macro ac:name="info"><ac:rich-text-body><p>Note text</p></ac:rich-text-body></ac:structured-macro>
        """
        let result = try ContentConverter.convert(xhtml: xhtml, imageMapping: [:], imageFolder: "")
        // SwiftSoup lowercases attributes — our serialize() must restore MadCap: casing
        #expect(result.contains("MadCap:autonum"))
        #expect(!result.contains("madcap:autonum"))
    }

    @Test("MadCap:autonum preserved on warning callout")
    func madcapAutonumWarning() throws {
        let xhtml = """
        <ac:structured-macro ac:name="warning"><ac:rich-text-body><p>Danger!</p></ac:rich-text-body></ac:structured-macro>
        """
        let result = try ContentConverter.convert(xhtml: xhtml, imageMapping: [:], imageFolder: "")
        #expect(result.contains("MadCap:autonum=\"<b>Warning: </b>\""))
    }

    @Test("MadCap:autonum preserved on tip callout")
    func madcapAutonumTip() throws {
        let xhtml = """
        <ac:structured-macro ac:name="tip"><ac:rich-text-body><p>Helpful!</p></ac:rich-text-body></ac:structured-macro>
        """
        let result = try ContentConverter.convert(xhtml: xhtml, imageMapping: [:], imageFolder: "")
        #expect(result.contains("MadCap:autonum=\"<b>Tip: </b>\""))
    }

    @Test("Multiple callout macros all preserve MadCap:autonum casing")
    func multipleMacrosMadCapCasing() throws {
        let xhtml = """
        <ac:structured-macro ac:name="info"><ac:rich-text-body><p>Info</p></ac:rich-text-body></ac:structured-macro>
        <ac:structured-macro ac:name="warning"><ac:rich-text-body><p>Warning</p></ac:rich-text-body></ac:structured-macro>
        <ac:structured-macro ac:name="tip"><ac:rich-text-body><p>Tip</p></ac:rich-text-body></ac:structured-macro>
        """
        let result = try ContentConverter.convert(xhtml: xhtml, imageMapping: [:], imageFolder: "")
        // Count occurrences of correct vs incorrect casing
        let correctCount = result.components(separatedBy: "MadCap:autonum").count - 1
        let incorrectCount = result.components(separatedBy: "madcap:autonum").count - 1
        #expect(correctCount == 3)
        #expect(incorrectCount == 0)
    }

    // MARK: - Full Pipeline (End-to-End Serialization)

    @Test("Full page conversion produces clean output without namespace remnants")
    func fullPageCleanOutput() throws {
        let xhtml = """
        <h1>Release Features</h1>
        <ac:structured-macro ac:name="info"><ac:rich-text-body><p>This release includes new features.</p></ac:rich-text-body></ac:structured-macro>
        <h2>New Features</h2>
        <ul>
            <li>Feature A</li>
            <li>Feature B</li>
        </ul>
        <p><ac:image ac:width="600"><ri:attachment ri:filename="feature_a.png" /></ac:image></p>
        <ac:structured-macro ac:name="warning"><ac:rich-text-body><p>Known issue with Feature B.</p></ac:rich-text-body></ac:structured-macro>
        <ac:layout><ac:layout-section><ac:layout-cell><p>Layout content</p></ac:layout-cell></ac:layout-section></ac:layout>
        """
        let result = try ContentConverter.convert(
            xhtml: xhtml,
            imageMapping: ["feature_a.png": "feature_a.png"],
            imageFolder: "09-Mar-2026"
        )

        // No Confluence namespace remnants
        #expect(!result.contains("<ac:"))
        #expect(!result.contains("</ac:"))
        #expect(!result.contains("<ri:"))
        #expect(!result.contains("</ri:"))

        // H1 demoted
        #expect(!result.contains("<h1>"))
        #expect(result.contains("<h2>"))

        // Image converted
        #expect(result.contains("<img"))
        #expect(result.contains("09-Mar-2026/feature_a.png"))

        // Macros converted with correct MadCap casing
        #expect(result.contains("MadCap:autonum"))
        #expect(!result.contains("madcap:autonum"))

        // Content preserved
        #expect(result.contains("Feature A"))
        #expect(result.contains("Feature B"))
        #expect(result.contains("Layout content"))
        #expect(result.contains("Known issue with Feature B"))
    }

    @Test("Output has no excessive blank lines")
    func noExcessiveBlankLines() throws {
        let xhtml = """
        <p>Line 1</p>


        <p></p>
        <p>   </p>


        <p>Line 2</p>
        """
        let result = try ContentConverter.convert(xhtml: xhtml, imageMapping: [:], imageFolder: "")
        // Should not have 3+ consecutive newlines
        #expect(!result.contains("\n\n\n"))
    }

    // MARK: - Template Rendering (Full HTM Output)

    @Test("TemplateRenderer produces valid Flare XML structure")
    func templateRendererOutput() throws {
        let bodyContent = """
        <h2>New Features</h2>
        <div class="note" MadCap:autonum="<b>Note: </b>"><p>Info here</p></div>
        <p>Content paragraph</p>
        """
        let output = TemplateRenderer.render(displayDate: "March 9, 2026", bodyContent: bodyContent)

        // XML declaration present
        #expect(output.contains("<?xml version=\"1.0\" encoding=\"utf-8\"?>"))

        // MadCap namespace with correct casing
        #expect(output.contains("xmlns:MadCap"))
        #expect(!output.contains("xmlns:madcap"))

        // MadCap:snippetBlock with correct casing
        #expect(output.contains("MadCap:snippetBlock"))
        #expect(!output.contains("madcap:snippetblock"))

        // Display date substituted
        #expect(output.contains("Release Notes - March 9, 2026"))
        #expect(output.contains("on March 9, 2026"))

        // Body content included
        #expect(output.contains("MadCap:autonum=\"<b>Note: </b>\""))
        #expect(output.contains("New Features"))
    }

    @Test("Width extraction works through full pipeline with self-closing tags")
    func widthExtractionFullPipeline() throws {
        let xhtml = "<p><ac:image ac:width=\"400\"><ri:attachment ri:filename=\"test.png\" /></ac:image></p>"
        let result = try ContentConverter.convert(xhtml: xhtml, imageMapping: ["test.png": "test.png"], imageFolder: "01-Feb-2026")
        #expect(result.contains("width: 400px"))
        #expect(result.contains("test.png"))
    }

    @Test("Full pipeline: Confluence XHTML → Flare HTM preserves all MadCap formatting")
    func fullPipelineConfluenceToFlare() throws {
        let xhtml = """
        <h1>COG Release Features</h1>
        <ac:structured-macro ac:name="info"><ac:rich-text-body><p>Updated dashboard widgets.</p></ac:rich-text-body></ac:structured-macro>
        <h2>Widget Builder</h2>
        <p>The widget builder now supports drag-and-drop.</p>
        <p><ac:image ac:width="500"><ri:attachment ri:filename="widget.png" /></ac:image></p>
        """

        // Step 1: Convert content (ContentConverter)
        let bodyContent = try ContentConverter.convert(
            xhtml: xhtml,
            imageMapping: ["widget.png": "widget.png"],
            imageFolder: "09-Mar-2026"
        )

        // Step 2: Render template (TemplateRenderer)
        let fullHTM = TemplateRenderer.render(displayDate: "March 9, 2026", bodyContent: bodyContent)

        // === SERIALIZATION CHECKS ===

        // XML declaration NOT commented out (SwiftSoup would produce <!--?xml...-->)
        #expect(!fullHTM.contains("<!--?xml"))
        #expect(fullHTM.contains("<?xml version=\"1.0\" encoding=\"utf-8\"?>"))

        // MadCap namespace NOT lowercased
        #expect(!fullHTM.contains("xmlns:madcap"))
        #expect(fullHTM.contains("xmlns:MadCap"))

        // MadCap:snippetBlock NOT lowercased
        #expect(!fullHTM.contains("madcap:snippetblock"))
        #expect(fullHTM.contains("MadCap:snippetBlock"))

        // MadCap:autonum NOT lowercased (from the info macro conversion)
        #expect(!fullHTM.contains("madcap:autonum"))
        #expect(fullHTM.contains("MadCap:autonum"))

        // Self-closing tags preserved (not expanded to <tag></tag>)
        // The template uses MadCap:snippetBlock which should remain self-closing
        #expect(fullHTM.contains("/>"))

        // Body content is present
        #expect(fullHTM.contains("Updated dashboard widgets"))
        #expect(fullHTM.contains("Widget Builder"))
        #expect(fullHTM.contains("drag-and-drop"))
        #expect(fullHTM.contains("widget.png"))

        // No Confluence artifacts leaked through
        #expect(!fullHTM.contains("<ac:"))
        #expect(!fullHTM.contains("<ri:"))
    }
}
