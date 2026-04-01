import Foundation
import os

/// Orchestrates the full import pipeline, yielding progress events via AsyncStream.
///
/// Mirrors the Python import_engine.py generator, replacing `yield` with
/// `AsyncStream.Continuation.yield`.
struct ImportEngine {
    private static let logger = Logger(subsystem: "ConfluenceToFlare", category: "ImportEngine")
    private static let manifestFilename = ".import_manifest.json"

    struct ManifestEntry: Codable {
        let confluencePageID: String
        let confluenceTitle: String
        let importedAt: String

        enum CodingKeys: String, CodingKey {
            case confluencePageID = "confluence_page_id"
            case confluenceTitle = "confluence_title"
            case importedAt = "imported_at"
        }
    }

    static func loadImportManifest(releaseNotesDir: URL) -> [String: ManifestEntry] {
        let manifestPath = releaseNotesDir.appendingPathComponent(manifestFilename)
        guard let data = try? Data(contentsOf: manifestPath),
              let manifest = try? JSONDecoder().decode([String: ManifestEntry].self, from: data) else {
            return [:]
        }
        return manifest
    }

    static func saveImportManifest(_ manifest: [String: ManifestEntry], releaseNotesDir: URL) {
        let manifestPath = releaseNotesDir.appendingPathComponent(manifestFilename)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(manifest) else { return }
        try? data.write(to: manifestPath)
    }

    static func getImportedPageIDs(releaseNotesDir: URL) -> Set<String> {
        let manifest = loadImportManifest(releaseNotesDir: releaseNotesDir)
        return Set(manifest.values.map(\.confluencePageID))
    }

    /// Get filenames of existing release note HTM files in the Flare project.
    static func getExistingReleases(releaseNotesDir: URL) -> Set<String> {
        let fm = FileManager.default
        guard fm.fileExists(atPath: releaseNotesDir.path) else { return Set() }

        do {
            let files = try fm.contentsOfDirectory(at: releaseNotesDir, includingPropertiesForKeys: nil)
            return Set(
                files.map(\.lastPathComponent)
                    .filter { $0.hasPrefix("Release Notes ") && $0.hasSuffix(".htm") }
            )
        } catch {
            return Set()
        }
    }

    /// Run the import pipeline, returning an AsyncStream of progress events.
    ///
    /// - Parameters:
    ///   - pageIDs: List of Confluence page IDs to import.
    ///   - client: Authenticated Confluence client.
    ///   - settings: App settings with Flare project paths.
    ///   - force: If true, overwrite existing Flare files.
    /// - Returns: AsyncStream of ImportEvent values.
    static func runImport(
        pageIDs: [String],
        client: ConfluenceClient,
        settings: AppSettings,
        force: Bool = false
    ) -> AsyncStream<ImportEvent> {
        AsyncStream { continuation in
            Task {
                let total = pageIDs.count
                continuation.yield(.start(total: total, message: "Starting import of \(total) page(s)"))

                // Validate paths
                guard let projectRoot = settings.resolvedProjectRoot,
                      FileManager.default.fileExists(atPath: projectRoot.path) else {
                    continuation.yield(.error(index: -1, message: "Flare project not found at \(settings.flareProjectRoot)"))
                    continuation.yield(.complete(imported: 0, skipped: 0, errors: 1, message: "Import failed"))
                    continuation.finish()
                    return
                }

                guard let releaseNotesDir = settings.resolvedReleaseNotesDir(),
                      let imagesDir = settings.resolvedImagesDir(),
                      let overviewFile = settings.resolvedOverviewFile(),
                      let tocFile = settings.resolvedTocFile() else {
                    continuation.yield(.error(index: -1, message: "Could not resolve Flare project paths"))
                    continuation.yield(.complete(imported: 0, skipped: 0, errors: 1, message: "Import failed"))
                    continuation.finish()
                    return
                }

                var manifest = loadImportManifest(releaseNotesDir: releaseNotesDir)
                let importedPageIDs = getImportedPageIDs(releaseNotesDir: releaseNotesDir)

                var importedCount = 0
                var skippedCount = 0
                var errorCount = 0

                for (i, pageID) in pageIDs.enumerated() {
                    // Check for cancellation
                    if Task.isCancelled {
                        continuation.yield(.error(index: -1, message: "Import cancelled"))
                        break
                    }

                    do {
                        // Fetch title
                        let title = try await client.getPageTitle(pageID: pageID)
                        continuation.yield(.pageStart(index: i, pageID: pageID, title: title, message: "Importing: \(title)"))

                        // Parse date
                        guard let dt = DateParser.parseConfluenceTitle(title) else {
                            continuation.yield(.error(index: i, message: "Could not parse date from title: \(title)"))
                            errorCount += 1
                            continue
                        }

                        let filename = DateParser.formatFlareFilename(dt)
                        let displayDate = DateParser.formatDisplayDate(dt)
                        let imageFolderName = DateParser.formatImageFolder(dt)

                        // Check if already imported (by Confluence page ID)
                        if importedPageIDs.contains(pageID) && !force {
                            continuation.yield(.skip(index: i, filename: filename, message: "Already exists: \(filename)"))
                            skippedCount += 1
                            continue
                        }

                        // Step 1: Download images
                        continuation.yield(.step(index: i, step: "images", message: "Downloading images..."))
                        let imageDest = try ImageHandler.createImageFolder(imagesBase: imagesDir, folderName: imageFolderName)
                        let imageMapping = try await ImageHandler.downloadAndPlaceImages(client: client, pageID: pageID, destFolder: imageDest)
                        let imgCount = imageMapping.count
                        continuation.yield(.step(index: i, step: "images_done", message: "Downloaded \(imgCount) image(s)"))

                        if Task.isCancelled { break }

                        // Step 2: Fetch and convert content
                        continuation.yield(.step(index: i, step: "content", message: "Converting page content..."))
                        let xhtml = try await client.getPageContent(pageID: pageID)
                        let bodyContent = try ContentConverter.convert(xhtml: xhtml, imageMapping: imageMapping, imageFolder: imageFolderName)
                        continuation.yield(.step(index: i, step: "content_done", message: "Converted page content"))

                        if Task.isCancelled { break }

                        // Step 3: Render template
                        continuation.yield(.step(index: i, step: "render", message: "Rendering Flare topic..."))
                        let htm = TemplateRenderer.render(displayDate: displayDate, bodyContent: bodyContent)
                        continuation.yield(.step(index: i, step: "render_done", message: "Rendered Flare topic"))

                        // Step 4: Write HTM file
                        continuation.yield(.step(index: i, step: "write", message: "Writing \(filename)..."))
                        let destFile = releaseNotesDir.appendingPathComponent(filename)
                        try FileManager.default.createDirectory(at: destFile.deletingLastPathComponent(), withIntermediateDirectories: true)
                        try BOMWriter.write(htm, to: destFile)
                        continuation.yield(.step(index: i, step: "write_done", message: "Wrote \(filename)"))

                        // Step 5: Update Overview page
                        continuation.yield(.step(index: i, step: "overview", message: "Updating Overview page..."))
                        try FlareUpdater.updateOverviewPage(
                            overviewPath: overviewFile,
                            filename: filename,
                            linkText: DateParser.formatOverviewLinkText(dt),
                            releaseDate: dt
                        )
                        continuation.yield(.step(index: i, step: "overview_done", message: "Updated Overview page"))

                        // Step 6: Update Mini-TOC
                        continuation.yield(.step(index: i, step: "toc", message: "Updating Mini-TOC..."))
                        try FlareUpdater.updateMiniToc(
                            tocPath: tocFile,
                            filename: filename,
                            tocTitle: DateParser.formatTocTitle(dt),
                            releaseDate: dt
                        )
                        continuation.yield(.step(index: i, step: "toc_done", message: "Updated Mini-TOC"))

                        // Page complete
                        continuation.yield(.pageDone(index: i, filename: filename, message: "Complete: \(filename)"))
                        importedCount += 1

                        // Record in import manifest
                        manifest[filename] = ManifestEntry(
                            confluencePageID: pageID,
                            confluenceTitle: title,
                            importedAt: ISO8601DateFormatter().string(from: Date())
                        )
                        ImportEngine.saveImportManifest(manifest, releaseNotesDir: releaseNotesDir)

                    } catch {
                        logger.error("Error importing page \(pageID): \(error.localizedDescription)")
                        continuation.yield(.error(index: i, message: error.localizedDescription))
                        errorCount += 1
                    }
                }

                // Final summary
                continuation.yield(.complete(
                    imported: importedCount,
                    skipped: skippedCount,
                    errors: errorCount,
                    message: "Import complete: \(importedCount) imported, \(skippedCount) skipped, \(errorCount) error(s)"
                ))
                continuation.finish()
            }
        }
    }
}
