import Foundation

// MARK: - Confluence REST API v2 (Pages)

/// Response wrapper for paginated page results.
struct PageListResponse: Decodable {
    let results: [PageResult]
    let _links: PaginationLinks?

    enum CodingKeys: String, CodingKey {
        case results
        case _links
    }
}

struct PageResult: Decodable {
    let id: String
    let title: String
    let status: String?
    let body: PageBody?
}

struct PageBody: Decodable {
    let storage: StorageBody?
}

struct StorageBody: Decodable {
    let value: String?
}

struct PaginationLinks: Decodable {
    let next: String?
}

// MARK: - Confluence REST API v1 (Attachments)

struct AttachmentListResponse: Decodable {
    let results: [AttachmentResult]
    let _links: PaginationLinks?

    enum CodingKeys: String, CodingKey {
        case results
        case _links
    }
}

struct AttachmentResult: Decodable {
    let title: String
    let extensions: AttachmentExtensions?
    let metadata: AttachmentMetadata?
    let _links: AttachmentLinks

    enum CodingKeys: String, CodingKey {
        case title, extensions, metadata
        case _links
    }

    var mediaType: String {
        extensions?.mediaType ?? metadata?.mediaType ?? ""
    }
}

struct AttachmentExtensions: Decodable {
    let mediaType: String?
}

struct AttachmentMetadata: Decodable {
    let mediaType: String?
}

struct AttachmentLinks: Decodable {
    let download: String
}
