import Foundation

/// A Confluence release note page with parsed metadata for display in the UI.
struct ConfluencePage: Identifiable, Hashable {
    let id: String
    let title: String
    let type: PageType
    let parsedDate: Date?
    let displayDate: String
    let flareFilename: String
    var isImported: Bool

    enum PageType: String, Hashable {
        case features = "Features"
        case patch = "Patch"
        case other = "Other"
    }

    /// Create from a Confluence API response dict-like data.
    init(id: String, title: String, type: PageType, importedPageIDs: Set<String>) {
        self.id = id
        self.title = title
        self.type = type
        self.parsedDate = DateParser.parseConfluenceTitle(title)

        if let date = parsedDate {
            self.displayDate = DateParser.formatDisplayDate(date)
            self.flareFilename = DateParser.formatFlareFilename(date)
        } else {
            self.displayDate = ""
            self.flareFilename = ""
        }

        self.isImported = importedPageIDs.contains(id)
    }
}
