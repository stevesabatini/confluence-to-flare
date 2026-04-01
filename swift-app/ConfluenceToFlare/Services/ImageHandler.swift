import Foundation
import os

/// Downloads image attachments from Confluence and places them in the Flare project.
///
/// Images are placed in dated subfolders under the "From Confluence"
/// Release Notes images directory, using the original Confluence
/// filenames to match the existing convention.
struct ImageHandler {
    private static let logger = Logger(subsystem: "ConfluenceToFlare", category: "ImageHandler")

    /// Image MIME types we handle.
    static let imageTypes: Set<String> = [
        "image/png", "image/jpeg", "image/gif", "image/svg+xml", "image/webp",
    ]

    /// Create the dated image folder if it doesn't exist.
    ///
    /// - Parameters:
    ///   - imagesBase: Base images directory URL.
    ///   - folderName: Date-based folder name, e.g. "05-Jan-2026".
    /// - Returns: URL to the created folder.
    static func createImageFolder(imagesBase: URL, folderName: String) throws -> URL {
        let folder = imagesBase.appendingPathComponent(folderName)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }

    /// Download all image attachments from a Confluence page.
    ///
    /// - Parameters:
    ///   - client: Authenticated Confluence client.
    ///   - pageID: Confluence page ID.
    ///   - destFolder: Local folder URL to save images into.
    /// - Returns: Mapping of {confluence_filename: local_filename}.
    static func downloadAndPlaceImages(
        client: ConfluenceClient,
        pageID: String,
        destFolder: URL
    ) async throws -> [String: String] {
        let attachments = try await client.getPageAttachments(pageID: pageID)
        let imageAttachments = attachments.filter { imageTypes.contains($0.mediaType) }

        if imageAttachments.isEmpty {
            logger.info("  No image attachments found")
            return [:]
        }

        logger.info("  Downloading \(imageAttachments.count) image(s)...")
        var mapping: [String: String] = [:]

        for attachment in imageAttachments {
            let confluenceName = attachment.title
            let localName = confluenceName
            let downloadPath = attachment._links.download
            let destFile = destFolder.appendingPathComponent(localName)

            try await client.downloadAttachment(downloadPath: downloadPath, dest: destFile)
            mapping[confluenceName] = localName
            logger.info("    \(confluenceName)")
        }

        return mapping
    }
}
