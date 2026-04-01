import Testing
import Foundation
@testable import ConfluenceToFlare

@Suite("FlareUpdater Tests")
struct FlareUpdaterTests {

    // MARK: - Overview Page

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

        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

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

        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

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

    // MARK: - BOM Writer

    @Test("BOMWriter prepends UTF-8 BOM")
    func bomWriterPrependsBOM() throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let file = tempDir.appendingPathComponent("test.htm")
        try BOMWriter.write("Hello", to: file)

        let data = try Data(contentsOf: file)
        // UTF-8 BOM is EF BB BF
        #expect(data[0] == 0xEF)
        #expect(data[1] == 0xBB)
        #expect(data[2] == 0xBF)
    }
}
