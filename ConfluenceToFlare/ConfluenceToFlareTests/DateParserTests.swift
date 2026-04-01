import Testing
import Foundation
@testable import ConfluenceToFlare

@Suite("DateParser Tests")
struct DateParserTests {

    // MARK: - Title Parsing

    @Test("Parse standard format with ordinal and 2-digit year")
    func parseStandard2DigitYear() {
        let date = DateParser.parseConfluenceTitle("COG Release Features(Production)-05thJan'26")
        #expect(date != nil)
        let components = Calendar.current.dateComponents([.year, .month, .day], from: date!)
        #expect(components.year == 2026)
        #expect(components.month == 1)
        #expect(components.day == 5)
    }

    @Test("Parse standard format with ordinal and 4-digit year")
    func parseStandard4DigitYear() {
        let date = DateParser.parseConfluenceTitle("COG_Technical Release Notes-02ndNov'2020")
        #expect(date != nil)
        let components = Calendar.current.dateComponents([.year, .month, .day], from: date!)
        #expect(components.year == 2020)
        #expect(components.month == 11)
        #expect(components.day == 2)
    }

    @Test("Parse full month name")
    func parseFullMonthName() {
        let date = DateParser.parseConfluenceTitle("COG Technical Release Notes(Production)-22ndApril'2024")
        #expect(date != nil)
        let components = Calendar.current.dateComponents([.year, .month, .day], from: date!)
        #expect(components.year == 2024)
        #expect(components.month == 4)
        #expect(components.day == 22)
    }

    @Test("Parse no ordinal suffix")
    func parseNoOrdinal() {
        let date = DateParser.parseConfluenceTitle("COG Release Features(Production)-03Jun'2024")
        #expect(date != nil)
        let components = Calendar.current.dateComponents([.year, .month, .day], from: date!)
        #expect(components.year == 2024)
        #expect(components.month == 6)
        #expect(components.day == 3)
    }

    @Test("Parse apostrophe before month")
    func parseApostropheBeforeMonth() {
        let date = DateParser.parseConfluenceTitle("COG_ReleaseFeatures_15th'Dec2021")
        #expect(date != nil)
        let components = Calendar.current.dateComponents([.year, .month, .day], from: date!)
        #expect(components.year == 2021)
        #expect(components.month == 12)
        #expect(components.day == 15)
    }

    @Test("Parse uppercase month")
    func parseUppercaseMonth() {
        let date = DateParser.parseConfluenceTitle("COG_ReleaseFeatures-21stNOV'2022")
        #expect(date != nil)
        let components = Calendar.current.dateComponents([.year, .month, .day], from: date!)
        #expect(components.year == 2022)
        #expect(components.month == 11)
        #expect(components.day == 21)
    }

    @Test("Parse patch release notes")
    func parsePatchRelease() {
        let date = DateParser.parseConfluenceTitle("COG Technical Patch Release Notes(Production)-13thJan'26")
        #expect(date != nil)
        let components = Calendar.current.dateComponents([.year, .month, .day], from: date!)
        #expect(components.year == 2026)
        #expect(components.month == 1)
        #expect(components.day == 13)
    }

    @Test("Return nil for unparseable title")
    func parseUnparseable() {
        let date = DateParser.parseConfluenceTitle("Some Random Page Title")
        #expect(date == nil)
    }

    @Test("Return nil for empty title")
    func parseEmpty() {
        let date = DateParser.parseConfluenceTitle("")
        #expect(date == nil)
    }

    // MARK: - Filename Formatting

    @Test("Format Flare filename")
    func formatFlareFilename() {
        let date = DateParser.parseConfluenceTitle("COG Release Features(Production)-05thJan'26")!
        let filename = DateParser.formatFlareFilename(date)
        #expect(filename == "Release Notes 2026-Jan-05.htm")
    }

    // MARK: - Image Folder Formatting

    @Test("Format image folder name")
    func formatImageFolder() {
        let date = DateParser.parseConfluenceTitle("COG Release Features(Production)-05thJan'26")!
        let folder = DateParser.formatImageFolder(date)
        #expect(folder == "05-Jan-2026")
    }

    // MARK: - Display Date Formatting

    @Test("Format display date")
    func formatDisplayDate() {
        let date = DateParser.parseConfluenceTitle("COG Release Features(Production)-05thJan'26")!
        let display = DateParser.formatDisplayDate(date)
        #expect(display == "January 5, 2026")
    }

    // MARK: - Overview Link Text

    @Test("Format overview link text")
    func formatOverviewLinkText() {
        let date = DateParser.parseConfluenceTitle("COG Release Features(Production)-05thJan'26")!
        let linkText = DateParser.formatOverviewLinkText(date)
        #expect(linkText == "Release: January 5, 2026")
    }

    // MARK: - Filename Date Parsing

    @Test("Parse date from Flare filename")
    func parseDateFromFilename() {
        let date = DateParser.parseDateFromFilename("Release Notes 2026-Jan-05.htm")
        #expect(date != nil)
        let components = Calendar.current.dateComponents([.year, .month, .day], from: date!)
        #expect(components.year == 2026)
        #expect(components.month == 1)
        #expect(components.day == 5)
    }

    @Test("Parse date from filename returns nil for non-matching")
    func parseDateFromFilenameNonMatching() {
        let date = DateParser.parseDateFromFilename("SomeOtherFile.htm")
        #expect(date == nil)
    }
}
