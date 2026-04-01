import Foundation

/// Parses dates from Confluence page titles and formats them for Flare output.
///
/// Handles various Confluence naming conventions:
///   "COG Release Features(Production)-05thJan'26"         (2-digit year)
///   "COG_Technical Release Notes-02ndNov'2020"             (4-digit year)
///   "COG Technical Release Notes(Production)-22ndApril'2024" (full month)
///   "COG Release Features(Production)-03Jun'2024"          (no ordinal)
///   "COG_ReleaseFeatures_15th'Dec2021"                     (apostrophe before month)
struct DateParser {

    // MARK: - Regex Patterns

    /// Primary: day with ordinal + month + apostrophe-year
    /// Matches: "05thJan'26", "02ndNov'2020", "22ndApril'2024"
    private static let datePattern = #/(\d{1,2})(?:st|nd|rd|th)([A-Za-z]{3,9})'(\d{2,4})$/#

    /// Fallback: day WITHOUT ordinal + 3-letter month + apostrophe-year
    /// Matches: "03Jun'2024", "05Aug'2024"
    private static let datePatternNoOrdinal = #/(\d{1,2})([A-Z][a-z]{2})'(\d{2,4})$/#

    /// Edge case: day with ordinal + apostrophe before month + 4-digit year
    /// Matches: "15th'Dec2021"
    private static let datePatternAlt = #/(\d{1,2})(?:st|nd|rd|th)'([A-Z][a-z]{2})(\d{4})$/#

    // MARK: - Month Normalization

    /// Map full month names to 3-letter abbreviations.
    private static let monthNormalize: [String: String] = [
        "january": "Jan", "february": "Feb", "march": "Mar",
        "april": "Apr", "may": "May", "june": "Jun",
        "july": "Jul", "august": "Aug", "september": "Sep",
        "october": "Oct", "november": "Nov", "december": "Dec",
    ]

    /// Convert a month string (3-letter, full name, any case) to 3-letter title case.
    private static func normalizeMonth(_ monthStr: String) -> String {
        let lower = monthStr.lowercased()
        if let abbreviated = monthNormalize[lower] {
            return abbreviated
        }
        // Already a 3-letter abbreviation — title-case it
        return monthStr.prefix(1).uppercased() + monthStr.dropFirst().prefix(2).lowercased()
    }

    // MARK: - Shared DateFormatter

    private static let parseDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "d MMM yyyy"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    // MARK: - Parse

    /// Extract a date from a Confluence release note page title.
    /// Returns nil if the title doesn't match any expected format.
    static func parseConfluenceTitle(_ title: String) -> Date? {
        let trimmed = title.trimmingCharacters(in: .whitespaces)

        let dayStr: Substring
        let monthRaw: Substring
        let yearStr: Substring

        if let match = trimmed.firstMatch(of: datePattern) {
            dayStr = match.output.1
            monthRaw = match.output.2
            yearStr = match.output.3
        } else if let match = trimmed.firstMatch(of: datePatternNoOrdinal) {
            dayStr = match.output.1
            monthRaw = match.output.2
            yearStr = match.output.3
        } else if let match = trimmed.firstMatch(of: datePatternAlt) {
            dayStr = match.output.1
            monthRaw = match.output.2
            yearStr = match.output.3
        } else {
            return nil
        }

        guard let day = Int(dayStr) else { return nil }
        let monthAbbr = normalizeMonth(String(monthRaw))

        let year: Int
        if yearStr.count == 2 {
            year = 2000 + (Int(yearStr) ?? 0)
        } else {
            guard let y = Int(yearStr) else { return nil }
            year = y
        }

        return parseDateFormatter.date(from: "\(day) \(monthAbbr) \(year)")
    }

    // MARK: - Format

    /// Format as Flare filename: "Release Notes 2026-Jan-05.htm"
    static func formatFlareFilename(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MMM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return "Release Notes \(f.string(from: date)).htm"
    }

    /// Format as image folder name: "05-Jan-2026"
    static func formatImageFolder(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "dd-MMM-yyyy"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f.string(from: date)
    }

    /// Format for display in headings: "January 5, 2026"
    static func formatDisplayDate(_ date: Date) -> String {
        let calendar = Calendar(identifier: .gregorian)
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        let f = DateFormatter()
        f.dateFormat = "MMMM"
        f.locale = Locale(identifier: "en_US_POSIX")
        let monthName = f.string(from: date)
        return "\(monthName) \(components.day!), \(components.year!)"
    }

    /// Format for TOC entry title: "January 5, 2026" (same as display date)
    static func formatTocTitle(_ date: Date) -> String {
        formatDisplayDate(date)
    }

    /// Format for Overview page link text: "Release: January 5, 2026"
    static func formatOverviewLinkText(_ date: Date) -> String {
        "Release: \(formatDisplayDate(date))"
    }

    /// Parse date from a Flare release notes filename.
    /// Matches: "Release Notes 2026-Jan-05.htm"
    static func parseDateFromFilename(_ filename: String) -> Date? {
        let pattern = #/Release Notes (\d{4})-([A-Za-z]{3})-(\d{2})\.htm/#
        guard let match = filename.firstMatch(of: pattern) else { return nil }
        let dateString = "\(match.output.1)-\(match.output.2)-\(match.output.3)"
        let f = DateFormatter()
        f.dateFormat = "yyyy-MMM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f.date(from: dateString)
    }
}
