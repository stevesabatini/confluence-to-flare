import Foundation

/// Writes files with UTF-8 BOM character, as required by MadCap Flare.
struct BOMWriter {
    /// The UTF-8 BOM character.
    static let bom = "\u{FEFF}"

    /// Write content to a file with UTF-8 BOM prepended.
    ///
    /// - Parameters:
    ///   - content: The text content to write.
    ///   - url: The file URL to write to.
    static func write(_ content: String, to url: URL) throws {
        let fullContent = bom + content
        try fullContent.write(to: url, atomically: true, encoding: .utf8)
    }
}
