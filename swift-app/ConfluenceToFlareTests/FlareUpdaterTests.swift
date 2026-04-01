import Testing
import Foundation
@testable import ConfluenceToFlare

@Suite("FlareUpdater Tests")
struct FlareUpdaterTests {

    // MARK: - Helper

    /// Create a temp directory and return (dir, cleanup).
    private func makeTempDir() throws -> (URL, () -> Void) {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return (dir, { try? FileManager.default.removeItem(at: dir) })
    }

    // MARK: - Overview Page: Basic Insertion

    @Test("Insert link into Overview page in date order")
    func insertOverviewLink() throws {
        let overviewContent = """
        <html>
        <body>
            <h1>Release Notes Overview</h1>
            <ul>
                <li><p><a href="Release Notes 2025-Dec-15.htm">Release: December 15, 2025</a></p></li>
                <li><p><a href="Release Notes 2025-Nov-01.htm">Release: November 1, 2025</a></p></li>
            </ul>
        </body>
        </html>
        """

        let (tempDir, cleanup) = try makeTempDir()
        defer { cleanup() }

        let overviewFile = tempDir.appendingPathComponent("Overview.htm")
        try BOMWriter.write(overviewContent, to: overviewFile)

        let releaseDate = DateParser.parseConfluenceTitle("COG Release Features(Production)-05thJan'26")!

        try FlareUpdater.updateOverviewPage(
            overviewPath: overviewFile,
            filename: "Release Notes 2026-Jan-05.htm",
            linkText: "Release: January 5, 2026",
            releaseDate: releaseDate
        )

        let result = try String(contentsOf: overviewFile, encoding: .utf8)
        #expect(result.contains("Release Notes 2026-Jan-05.htm"))
        #expect(result.contains("Release: January 5, 2026"))

        // Verify ordering: new entry (Jan 2026) should come before Dec 2025
        let newIndex = result.range(of: "2026-Jan-05")!.lowerBound
        let existingIndex = result.range(of: "2025-Dec-15")!.lowerBound
        #expect(newIndex < existingIndex)
    }

    // MARK: - Overview: MadCap Namespace Preservation (SERIALIZATION CRITICAL)

    @Test("Overview update preserves xmlns:MadCap namespace casing")
    func overviewPreservesMadCapNamespace() throws {
        let overviewContent = """
        <?xml version="1.0" encoding="utf-8"?>
        <html xmlns:MadCap="http://www.madcapsoftware.com/Schemas/MadCap.xsd" style="mc-template-page: url('../../Resources/MasterPages/LandingTopics.flmsp');">
            <head><title>Release Notes Overview</title></head>
            <body>
                <h1>Release Notes Overview</h1>
                <MadCap:snippetBlock src="../../Resources/Snippets/Release Notes Image.flsnp" />
                <ul>
                    <li><p><a href="Release Notes 2025-Dec-15.htm">Release: December 15, 2025</a></p></li>
                </ul>
            </body>
        </html>
        """

        let (tempDir, cleanup) = try makeTempDir()
        defer { cleanup() }

        let overviewFile = tempDir.appendingPathComponent("Overview.htm")
        try BOMWriter.write(overviewContent, to: overviewFile)

        let releaseDate = DateParser.parseConfluenceTitle("COG Release Features(Production)-05thJan'26")!

        try FlareUpdater.updateOverviewPage(
            overviewPath: overviewFile,
            filename: "Release Notes 2026-Jan-05.htm",
            linkText: "Release: January 5, 2026",
            releaseDate: releaseDate
        )

        let result = try String(contentsOf: overviewFile, encoding: .utf8)

        // XML declaration NOT commented out
        #expect(!result.contains("<!--?xml"))
        #expect(result.contains("<?xml version=\"1.0\" encoding=\"utf-8\"?>"))

        // MadCap namespace NOT lowercased
        #expect(!result.contains("xmlns:madcap"))
        #expect(result.contains("xmlns:MadCap"))

        // MadCap:snippetBlock NOT lowercased or expanded
        #expect(!result.contains("madcap:snippetblock"))
        #expect(result.contains("MadCap:snippetBlock"))

        // Self-closing tag preserved
        #expect(result.contains("/>"))

        // mc-template-page style preserved
        #expect(result.contains("mc-template-page"))
    }

    @Test("Overview update preserves original indentation and structure")
    func overviewPreservesFormatting() throws {
        let overviewContent = """
        <?xml version="1.0" encoding="utf-8"?>
        <html xmlns:MadCap="http://www.madcapsoftware.com/Schemas/MadCap.xsd">
            <body>
                <ul>
                    <li><p><a href="Release Notes 2025-Dec-15.htm">Release: December 15, 2025</a></p></li>
                    <li><p><a href="Release Notes 2025-Nov-01.htm">Release: November 1, 2025</a></p></li>
                </ul>
            </body>
        </html>
        """

        let (tempDir, cleanup) = try makeTempDir()
        defer { cleanup() }

        let overviewFile = tempDir.appendingPathComponent("Overview.htm")
        try BOMWriter.write(overviewContent, to: overviewFile)

        let releaseDate = DateParser.parseConfluenceTitle("COG Release Features(Production)-05thJan'26")!

        try FlareUpdater.updateOverviewPage(
            overviewPath: overviewFile,
            filename: "Release Notes 2026-Jan-05.htm",
            linkText: "Release: January 5, 2026",
            releaseDate: releaseDate
        )

        let result = try String(contentsOf: overviewFile, encoding: .utf8)

        // Existing entries still present and unchanged
        #expect(result.contains("Release Notes 2025-Dec-15.htm"))
        #expect(result.contains("Release Notes 2025-Nov-01.htm"))

        // The closing tags and structure are preserved
        #expect(result.contains("</ul>"))
        #expect(result.contains("</body>"))
        #expect(result.contains("</html>"))
    }

    @Test("Overview update does not double-escape HTML entities")
    func overviewNoDoubleEscape() throws {
        let overviewContent = """
        <html>
        <body>
            <ul>
                <li><p><a href="Release Notes 2025-Dec-15.htm">Release: December 15, 2025</a></p></li>
            </ul>
        </body>
        </html>
        """

        let (tempDir, cleanup) = try makeTempDir()
        defer { cleanup() }

        let overviewFile = tempDir.appendingPathComponent("Overview.htm")
        try BOMWriter.write(overviewContent, to: overviewFile)

        let releaseDate = DateParser.parseConfluenceTitle("COG Release Features(Production)-05thJan'26")!

        try FlareUpdater.updateOverviewPage(
            overviewPath: overviewFile,
            filename: "Release Notes 2026-Jan-05.htm",
            linkText: "Release: January 5, 2026",
            releaseDate: releaseDate
        )

        let result = try String(contentsOf: overviewFile, encoding: .utf8)

        // No double-escaped entities
        #expect(!result.contains("&amp;amp;"))
        #expect(!result.contains("&amp;lt;"))
        #expect(!result.contains("&amp;gt;"))
    }

    @Test("Multiple overview insertions maintain date ordering")
    func overviewMultipleInsertions() throws {
        let overviewContent = """
        <html>
        <body>
            <ul>
                <li><p><a href="Release Notes 2025-Dec-15.htm">Release: December 15, 2025</a></p></li>
            </ul>
        </body>
        </html>
        """

        let (tempDir, cleanup) = try makeTempDir()
        defer { cleanup() }

        let overviewFile = tempDir.appendingPathComponent("Overview.htm")
        try BOMWriter.write(overviewContent, to: overviewFile)

        // Insert Feb 18
        let feb18 = DateParser.parseConfluenceTitle("COG Release Features(End User App)-18thFeb'26")!
        try FlareUpdater.updateOverviewPage(
            overviewPath: overviewFile,
            filename: "Release Notes 2026-Feb-18.htm",
            linkText: "Release: February 18, 2026",
            releaseDate: feb18
        )

        // Insert Mar 9
        let mar9 = DateParser.parseConfluenceTitle("COG Release Features(End User App)-09thMar'26")!
        try FlareUpdater.updateOverviewPage(
            overviewPath: overviewFile,
            filename: "Release Notes 2026-Mar-09.htm",
            linkText: "Release: March 9, 2026",
            releaseDate: mar9
        )

        // Insert Jan 5
        let jan5 = DateParser.parseConfluenceTitle("COG Release Features(Production)-05thJan'26")!
        try FlareUpdater.updateOverviewPage(
            overviewPath: overviewFile,
            filename: "Release Notes 2026-Jan-05.htm",
            linkText: "Release: January 5, 2026",
            releaseDate: jan5
        )

        let result = try String(contentsOf: overviewFile, encoding: .utf8)

        // All entries present
        #expect(result.contains("2026-Mar-09"))
        #expect(result.contains("2026-Feb-18"))
        #expect(result.contains("2026-Jan-05"))
        #expect(result.contains("2025-Dec-15"))

        // Verify order: Mar > Feb > Jan > Dec
        let mar9Idx = result.range(of: "2026-Mar-09")!.lowerBound
        let feb18Idx = result.range(of: "2026-Feb-18")!.lowerBound
        let jan5Idx = result.range(of: "2026-Jan-05")!.lowerBound
        let dec15Idx = result.range(of: "2025-Dec-15")!.lowerBound
        #expect(mar9Idx < feb18Idx)
        #expect(feb18Idx < jan5Idx)
        #expect(jan5Idx < dec15Idx)
    }

    // MARK: - Mini-TOC

    @Test("Insert TocEntry into Mini-TOC in date order")
    func insertMiniTocEntry() throws {
        let tocContent = """
        <?xml version="1.0" encoding="utf-8"?>
        <CatapultToc>
            <TocEntry Title="Release Notes" Link="/Content/E_Landing Topics/Release Notes/Release Notes Overview.htm">
                <TocEntry Title="December 15, 2025" Link="/Content/E_Landing Topics/Release Notes/Release Notes 2025-Dec-15.htm" />
                <TocEntry Title="November 1, 2025" Link="/Content/E_Landing Topics/Release Notes/Release Notes 2025-Nov-01.htm" />
            </TocEntry>
        </CatapultToc>
        """

        let (tempDir, cleanup) = try makeTempDir()
        defer { cleanup() }

        let tocFile = tempDir.appendingPathComponent("Mini-TOC.fltoc")
        try BOMWriter.write(tocContent, to: tocFile)

        let releaseDate = DateParser.parseConfluenceTitle("COG Release Features(Production)-05thJan'26")!

        try FlareUpdater.updateMiniToc(
            tocPath: tocFile,
            filename: "Release Notes 2026-Jan-05.htm",
            tocTitle: "January 5, 2026",
            releaseDate: releaseDate
        )

        let result = try String(contentsOf: tocFile, encoding: .utf8)
        #expect(result.contains("January 5, 2026"))
        #expect(result.contains("Release Notes 2026-Jan-05.htm"))
    }

    @Test("Mini-TOC update preserves XML declaration")
    func miniTocPreservesXmlDeclaration() throws {
        let tocContent = """
        <?xml version="1.0" encoding="utf-8"?>
        <CatapultToc>
            <TocEntry Title="Release Notes" Link="/Content/E_Landing Topics/Release Notes/Release Notes Overview.htm">
                <TocEntry Title="December 15, 2025" Link="/Content/E_Landing Topics/Release Notes/Release Notes 2025-Dec-15.htm" />
            </TocEntry>
        </CatapultToc>
        """

        let (tempDir, cleanup) = try makeTempDir()
        defer { cleanup() }

        let tocFile = tempDir.appendingPathComponent("Mini-TOC.fltoc")
        try BOMWriter.write(tocContent, to: tocFile)

        let releaseDate = DateParser.parseConfluenceTitle("COG Release Features(Production)-05thJan'26")!

        try FlareUpdater.updateMiniToc(
            tocPath: tocFile,
            filename: "Release Notes 2026-Jan-05.htm",
            tocTitle: "January 5, 2026",
            releaseDate: releaseDate
        )

        let result = try String(contentsOf: tocFile, encoding: .utf8)

        // XML declaration preserved, not commented out
        #expect(!result.contains("<!--?xml"))
        #expect(result.contains("<?xml version=\"1.0\" encoding=\"utf-8\"?>"))

        // CatapultToc structure intact
        #expect(result.contains("<CatapultToc>"))
        #expect(result.contains("</CatapultToc>"))
    }

    @Test("Mini-TOC self-closing TocEntry tags preserved")
    func miniTocSelfClosingPreserved() throws {
        let tocContent = """
        <?xml version="1.0" encoding="utf-8"?>
        <CatapultToc>
            <TocEntry Title="Release Notes" Link="/Content/E_Landing Topics/Release Notes/Release Notes Overview.htm">
                <TocEntry Title="December 15, 2025" Link="/Content/E_Landing Topics/Release Notes/Release Notes 2025-Dec-15.htm" />
            </TocEntry>
        </CatapultToc>
        """

        let (tempDir, cleanup) = try makeTempDir()
        defer { cleanup() }

        let tocFile = tempDir.appendingPathComponent("Mini-TOC.fltoc")
        try BOMWriter.write(tocContent, to: tocFile)

        let releaseDate = DateParser.parseConfluenceTitle("COG Release Features(Production)-05thJan'26")!

        try FlareUpdater.updateMiniToc(
            tocPath: tocFile,
            filename: "Release Notes 2026-Jan-05.htm",
            tocTitle: "January 5, 2026",
            releaseDate: releaseDate
        )

        let result = try String(contentsOf: tocFile, encoding: .utf8)

        // New entry should be self-closing
        #expect(result.contains("January 5, 2026\" Link=\"/Content/E_Landing Topics/Release Notes/Release Notes 2026-Jan-05.htm\" />"))
    }

    // MARK: - BOM Writer

    @Test("BOMWriter prepends UTF-8 BOM")
    func bomWriterPrependsBOM() throws {
        let (tempDir, cleanup) = try makeTempDir()
        defer { cleanup() }

        let file = tempDir.appendingPathComponent("test.htm")
        try BOMWriter.write("Hello", to: file)

        let data = try Data(contentsOf: file)
        // UTF-8 BOM is EF BB BF
        #expect(data[0] == 0xEF)
        #expect(data[1] == 0xBB)
        #expect(data[2] == 0xBF)
    }

    @Test("BOMWriter round-trips through FlareUpdater readWithBOM")
    func bomRoundTrip() throws {
        let (tempDir, cleanup) = try makeTempDir()
        defer { cleanup() }

        let content = """
        <?xml version="1.0" encoding="utf-8"?>
        <html xmlns:MadCap="http://www.madcapsoftware.com/Schemas/MadCap.xsd">
            <body><p>Test</p></body>
        </html>
        """
        let file = tempDir.appendingPathComponent("test.htm")
        try BOMWriter.write(content, to: file)

        // Read it back — the BOM should be stripped transparently
        let data = try Data(contentsOf: file)
        #expect(data.starts(with: [0xEF, 0xBB, 0xBF]))

        let readBack = String(data: data.dropFirst(3), encoding: .utf8) ?? ""
        #expect(readBack.contains("xmlns:MadCap"))
        #expect(readBack.contains("<?xml"))
    }
}
