import Foundation
import os

/// Confluence Cloud REST API client.
///
/// Uses basic auth (email + API token) to fetch release note pages,
/// their content in storage format (XHTML), and image attachments.
/// Implements exponential backoff on 429 rate limit responses.
actor ConfluenceClient {
    private let baseURL: String
    private let session: URLSession
    private let logger = Logger(subsystem: "ConfluenceToFlare", category: "ConfluenceClient")

    init(baseURL: String, email: String, apiToken: String) {
        self.baseURL = baseURL.hasSuffix("/") ? String(baseURL.dropLast()) : baseURL

        let config = URLSessionConfiguration.default
        let credentials = "\(email):\(apiToken)"
        let base64 = Data(credentials.utf8).base64EncodedString()
        config.httpAdditionalHeaders = [
            "Authorization": "Basic \(base64)",
            "Accept": "application/json",
        ]
        self.session = URLSession(configuration: config)
    }

    // MARK: - Errors

    enum ClientError: LocalizedError {
        case rateLimitExceeded
        case httpError(Int)
        case invalidResponse
        case invalidURL(String)

        var errorDescription: String? {
            switch self {
            case .rateLimitExceeded:
                return "Rate limit exceeded after 5 retries"
            case .httpError(let code):
                return "HTTP error \(code)"
            case .invalidResponse:
                return "Invalid response from Confluence"
            case .invalidURL(let url):
                return "Invalid URL: \(url)"
            }
        }
    }

    // MARK: - Core Request with Retry

    /// GET request with exponential backoff on 429.
    private func get(url: String, params: [String: String]? = nil) async throws -> Data {
        guard var components = URLComponents(string: url) else {
            throw ClientError.invalidURL(url)
        }

        if let params {
            components.queryItems = params.map { URLQueryItem(name: $0.key, value: $0.value) }
        }

        guard let requestURL = components.url else {
            throw ClientError.invalidURL(url)
        }

        for attempt in 0..<5 {
            let (data, response) = try await session.data(from: requestURL)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw ClientError.invalidResponse
            }

            if httpResponse.statusCode == 429 {
                let wait = UInt64(pow(2.0, Double(attempt))) * 1_000_000_000
                logger.warning("Rate limited (429), waiting \(Int(pow(2.0, Double(attempt))))s...")
                try await Task.sleep(nanoseconds: wait)
                continue
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                throw ClientError.httpError(httpResponse.statusCode)
            }

            return data
        }

        throw ClientError.rateLimitExceeded
    }

    /// GET request that returns decoded JSON.
    private func getJSON<T: Decodable>(_ type: T.Type, url: String, params: [String: String]? = nil) async throws -> T {
        let data = try await get(url: url, params: params)
        return try JSONDecoder().decode(type, from: data)
    }

    // MARK: - Page Operations (REST API v2)

    /// Fetch all immediate child pages of a given page.
    /// Handles cursor-based pagination automatically.
    func getChildPages(pageID: String) async throws -> [PageResult] {
        var url = "\(baseURL)/wiki/api/v2/pages/\(pageID)/children"
        var params: [String: String]? = ["limit": "50"]
        var allPages: [PageResult] = []

        while true {
            let response = try await getJSON(PageListResponse.self, url: url, params: params)
            allPages.append(contentsOf: response.results)

            guard let nextLink = response._links?.next else { break }
            url = "\(baseURL)\(nextLink)"
            params = nil // params are embedded in next_link
        }

        return allPages
    }

    /// Walk the Confluence hierarchy to find all customer-facing release pages.
    ///
    /// Expected hierarchy:
    ///   Production Environment (productionParentID)
    ///     → Production-YYYY folders
    ///       → COG Technical Release Notes(Production)-*
    ///         → COG Release Features(Production)-*  ← primary target
    ///       → COG Technical Patch Release Notes(Production)-*  ← also included
    func getReleaseFeaturePages(productionParentID: String) async throws -> [(id: String, title: String, type: String)] {
        var result: [(id: String, title: String, type: String)] = []

        // Level 1: Get Production-YYYY year folders
        let yearFolders = try await getChildPages(pageID: productionParentID)
        let productionFolders = yearFolders.filter {
            $0.title.lowercased().hasPrefix("production")
        }
        logger.info("Found \(productionFolders.count) year folder(s) under Production Environment")

        for yearFolder in productionFolders {
            logger.info("  Scanning \(yearFolder.title)...")

            // Level 2: Get release note pages within the year folder
            let releasePages = try await getChildPages(pageID: yearFolder.id)

            for page in releasePages {
                let title = page.title

                if title.contains("Patch") && title.contains("Release Notes") {
                    result.append((id: page.id, title: title, type: "patch"))
                    logger.info("    Found patch: \(title)")

                } else if title.contains("Technical Release Notes") || title.contains("Technical_Release Notes") {
                    let children = try await getChildPages(pageID: page.id)
                    let featuresChildren = children.filter {
                        $0.title.contains("Features") || $0.title.contains("Release Features")
                    }

                    if !featuresChildren.isEmpty {
                        for child in featuresChildren {
                            result.append((id: child.id, title: child.title, type: "features"))
                            logger.info("    Found features: \(child.title)")
                        }
                    } else {
                        result.append((id: page.id, title: title, type: "features"))
                        logger.info("    Found features (no child): \(title)")
                    }
                } else {
                    logger.debug("    Skipping non-release page: \(title)")
                }
            }
        }

        return result
    }

    /// Fetch page body in storage format (XHTML).
    func getPageContent(pageID: String) async throws -> String {
        let url = "\(baseURL)/wiki/api/v2/pages/\(pageID)"
        let params = ["body-format": "storage"]
        let response = try await getJSON(PageResult.self, url: url, params: params)
        return response.body?.storage?.value ?? ""
    }

    /// Fetch just the page title.
    func getPageTitle(pageID: String) async throws -> String {
        let url = "\(baseURL)/wiki/api/v2/pages/\(pageID)"
        let response = try await getJSON(PageResult.self, url: url)
        return response.title
    }

    // MARK: - Attachment Operations (REST API v1)

    /// List all attachments on a page.
    func getPageAttachments(pageID: String) async throws -> [AttachmentResult] {
        var url = "\(baseURL)/wiki/rest/api/content/\(pageID)/child/attachment"
        var params: [String: String]? = ["limit": "100", "expand": "version"]
        var allAttachments: [AttachmentResult] = []

        while true {
            let response = try await getJSON(AttachmentListResponse.self, url: url, params: params)
            allAttachments.append(contentsOf: response.results)

            guard let nextLink = response._links?.next else { break }
            url = "\(baseURL)\(nextLink)"
            params = nil
        }

        return allAttachments
    }

    /// Download an attachment binary to a local file.
    func downloadAttachment(downloadPath: String, dest: URL) async throws {
        let url = "\(baseURL)/wiki\(downloadPath)"
        guard let requestURL = URL(string: url) else {
            throw ClientError.invalidURL(url)
        }

        let (tempURL, response) = try await session.download(from: requestURL)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw ClientError.httpError((response as? HTTPURLResponse)?.statusCode ?? 0)
        }

        let fm = FileManager.default
        try fm.createDirectory(at: dest.deletingLastPathComponent(), withIntermediateDirectories: true)

        if fm.fileExists(atPath: dest.path) {
            try fm.removeItem(at: dest)
        }
        try fm.moveItem(at: tempURL, to: dest)
    }
}
