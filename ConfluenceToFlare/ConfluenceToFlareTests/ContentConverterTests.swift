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
        <ac:image ac:width="400"><ri:attachment ri:filename="test.png" /></ac:image>
        """
        let result = try ContentConverter.convert(
            xhtml: xhtml,
            imageMapping: ["test.png": "test.png"],
            imageFolder: "01-Feb-2026"
        )
        #expect(result.contains("width: 400px"))
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

    // MARK: - Empty Paragraph Removal

    @Test("Remove empty paragraphs")
    func removeEmptyParagraphs() throws {
        let xhtml = "<p>   </p><p>Real content</p><p></p>"
        let result = try ContentConverter.convert(xhtml: xhtml, imageMapping: [:], imageFolder: "")
        #expect(result.contains("Real content"))
        // Empty paragraphs should be removed
    }

    // MARK: - Namespace Cleanup

    @Test("Clean up leftover ac: and ri: tags in output")
    func cleanupNamespaceTags() throws {
        let xhtml = "<p>Content</p>"
        let result = try ContentConverter.convert(xhtml: xhtml, imageMapping: [:], imageFolder: "")
        #expect(!result.contains("<ac:"))
        #expect(!result.contains("<ri:"))
    }
}
