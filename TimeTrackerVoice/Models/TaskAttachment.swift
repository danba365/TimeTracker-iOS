import Foundation

/// A file attached to a task (uploaded from the web app, or a photo from the iOS Lists tab).
struct TaskAttachment: Codable, Identifiable, Hashable {
    let id: String
    let taskId: String
    let userId: String
    let fileName: String
    let mimeType: String
    let sizeBytes: Int
    let storagePath: String
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case taskId = "task_id"
        case userId = "user_id"
        case fileName = "file_name"
        case mimeType = "mime_type"
        case sizeBytes = "size_bytes"
        case storagePath = "storage_path"
        case createdAt = "created_at"
    }

    var isPDF: Bool { mimeType == "application/pdf" }
    var isImage: Bool { mimeType.hasPrefix("image/") }

    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: Int64(sizeBytes), countStyle: .file)
    }
}
