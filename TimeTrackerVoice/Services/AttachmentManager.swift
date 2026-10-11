import Foundation

/// Task attachments: list, paperclip index, signed download with a local cache,
/// plus photo upload/remove (used by social plans in the Lists tab).
@MainActor
final class AttachmentManager: ObservableObject {
    static let shared = AttachmentManager()

    enum AttachmentError: Error { case unavailable, failed }

    @Published private(set) var taskIdsWithAttachments: Set<String> = []
    /// Oldest image per task (thumbnails for social plans in the Lists tab).
    @Published private(set) var firstImageByTask: [String: TaskAttachment] = [:]

    private let bucket = "task-attachments"
    private let cacheRoot: URL = FileManager.default
        .urls(for: .cachesDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("attachments", isDirectory: true)

    private init() {}

    /// Which tasks have files (drives the paperclip in the task lists) and each task's first image.
    func refreshIndex() async {
        guard let url = URL(string: "\(Config.supabaseURL)/rest/v1/task_attachments?select=*&order=created_at.asc") else { return }
        do {
            let (data, http) = try await SupabaseRequest.send(url)
            guard http.statusCode == 200 else { return }
            let rows = try JSONDecoder().decode([TaskAttachment].self, from: data)
            taskIdsWithAttachments = Set(rows.map(\.taskId))
            var firstImages: [String: TaskAttachment] = [:]
            for row in rows where row.isImage && firstImages[row.taskId] == nil {
                firstImages[row.taskId] = row
            }
            firstImageByTask = firstImages
        } catch {
            print("⚠️ Attachment index refresh failed: \(error)")
        }
    }

    func attachments(for taskId: String) async throws -> [TaskAttachment] {
        guard let url = URL(string: "\(Config.supabaseURL)/rest/v1/task_attachments?task_id=eq.\(taskId)&order=created_at.asc") else {
            return []
        }
        let (data, http) = try await SupabaseRequest.send(url)
        guard http.statusCode == 200 else { throw AttachmentError.failed }
        return try JSONDecoder().decode([TaskAttachment].self, from: data)
    }

    /// Cached local copy, downloading through a 60-second signed URL when needed.
    func localFile(for attachment: TaskAttachment) async throws -> URL {
        let folder = cacheRoot.appendingPathComponent(attachment.id, isDirectory: true)
        let file = folder.appendingPathComponent(Self.localCacheName(attachment.fileName, mimeType: attachment.mimeType))
        if FileManager.default.fileExists(atPath: file.path) { return file }

        do {
            return try await download(attachment, folder: folder, file: file)
        } catch let error as AttachmentError {
            throw error
        } catch {
            throw AttachmentError.failed
        }
    }

    private func download(_ attachment: TaskAttachment, folder: URL, file: URL) async throws -> URL {

        guard let signURL = URL(string: "\(Config.supabaseURL)/storage/v1/object/sign/\(bucket)/\(attachment.storagePath)") else {
            throw AttachmentError.failed
        }
        let (data, http) = try await SupabaseRequest.send(signURL, method: "POST", json: ["expiresIn": 60])
        if http.statusCode == 400 || http.statusCode == 404 { throw AttachmentError.unavailable }
        guard http.statusCode == 200,
              let body = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let signedPath = body["signedURL"] as? String,
              let downloadURL = URL(string: "\(Config.supabaseURL)/storage/v1\(signedPath)") else {
            throw AttachmentError.failed
        }

        let (fileData, response) = try await URLSession.shared.data(from: downloadURL)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw AttachmentError.unavailable }
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try fileData.write(to: file, options: .atomic)
        return file
    }

    /// Filesystem-safe cache file name derived from the user-supplied name (display name is unchanged).
    static func localCacheName(_ fileName: String, mimeType: String? = nil) -> String {
        let cleaned = String(String.UnicodeScalarView(fileName.unicodeScalars.map { scalar in
            (scalar == "/" || scalar == ":" || scalar.properties.generalCategory == .control) ? "_" : scalar
        }))
        if cleaned.isEmpty || cleaned == "." || cleaned == ".." { return "file" }

        let ns = cleaned as NSString
        var ext = ns.pathExtension
        var base = ns.deletingPathExtension
        if ext.utf8.count > 20 { ext = ""; base = cleaned }
        // Quick Look decides by extension, so give extension-less names one from the MIME type.
        if ext.isEmpty, let mimeType {
            let byMime = ["application/pdf": "pdf", "image/jpeg": "jpg", "image/png": "png",
                          "image/heic": "heic", "image/heif": "heif", "image/webp": "webp"]
            ext = byMime[mimeType.lowercased()] ?? ""
        }
        let extPart = ext.isEmpty ? "" : "." + ext
        let maxBase = max(1, 120 - extPart.utf8.count)
        while base.utf8.count > maxBase { base.removeLast() }
        if base.isEmpty || base == "." || base == ".." { base = "file" }
        return base + extPart
    }

    /// Uploads a JPEG photo to `<uid>/<taskId>/` and records it on the task.
    func uploadPhoto(_ jpeg: Data, taskId: String) async throws -> TaskAttachment {
        guard let userId = AuthManager.shared.currentUser?.id else { throw AttachmentError.failed }
        let fileName = "photo-\(Self.photoStamp()).jpg"
        let path = "\(userId.lowercased())/\(taskId.lowercased())/\(UUID().uuidString.lowercased())-\(fileName)"
        guard let uploadURL = URL(string: "\(Config.supabaseURL)/storage/v1/object/\(bucket)/\(path)"),
              let rowsURL = URL(string: "\(Config.supabaseURL)/rest/v1/task_attachments") else {
            throw AttachmentError.failed
        }

        let (_, uploaded) = try await SupabaseRequest.send(
            uploadURL, method: "POST", body: jpeg,
            extraHeaders: ["Content-Type": "image/jpeg", "x-upsert": "false"]
        )
        guard uploaded.statusCode == 200 else { throw AttachmentError.failed }

        let row: [String: Any] = [
            "task_id": taskId, "user_id": userId, "file_name": fileName,
            "mime_type": "image/jpeg", "size_bytes": jpeg.count, "storage_path": path,
        ]
        let (data, inserted) = try await SupabaseRequest.send(
            rowsURL, method: "POST", json: row, extraHeaders: ["Prefer": "return=representation"]
        )
        guard inserted.statusCode == 201,
              let attachment = try? JSONDecoder().decode([TaskAttachment].self, from: data).first else {
            await removeObjects([path])  // don't leave an orphan object behind
            throw AttachmentError.failed
        }
        taskIdsWithAttachments.insert(taskId)
        return attachment
    }

    /// Removes one attachment: the stored file first, then its row (kept on failure so it can be retried).
    func remove(_ attachment: TaskAttachment) async throws {
        guard await removeObjects([attachment.storagePath]),
              let url = URL(string: "\(Config.supabaseURL)/rest/v1/task_attachments?id=eq.\(attachment.id)") else {
            throw AttachmentError.failed
        }
        let (_, http) = try await SupabaseRequest.send(url, method: "DELETE")
        guard (200..<300).contains(http.statusCode) else { throw AttachmentError.failed }
        try? FileManager.default.removeItem(at: cacheRoot.appendingPathComponent(attachment.id, isDirectory: true))
    }

    @discardableResult
    private func removeObjects(_ paths: [String]) async -> Bool {
        guard let url = URL(string: "\(Config.supabaseURL)/storage/v1/object/\(bucket)"),
              let (_, http) = try? await SupabaseRequest.send(url, method: "DELETE", json: ["prefixes": paths]) else {
            return false
        }
        return http.statusCode == 200
    }

    private static func photoStamp() -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyyMMdd-HHmmss"
        return f.string(from: Date())
    }

    /// Clear in-memory index and cached files (sign-out).
    func reset() {
        taskIdsWithAttachments = []
        firstImageByTask = [:]
        try? FileManager.default.removeItem(at: cacheRoot)
    }

    /// Best effort: remove a task's stored files before the task is deleted.
    func deleteFiles(forTask taskId: String) async {
        do {
            let items = try await attachments(for: taskId)
            let paths = items.map(\.storagePath)
            guard !paths.isEmpty,
                  let url = URL(string: "\(Config.supabaseURL)/storage/v1/object/\(bucket)") else { return }
            _ = try await SupabaseRequest.send(url, method: "DELETE", json: ["prefixes": paths])
            taskIdsWithAttachments.remove(taskId)
            for item in items {
                try? FileManager.default.removeItem(at: cacheRoot.appendingPathComponent(item.id, isDirectory: true))
            }
        } catch {
            print("⚠️ Could not remove attachment files: \(error)")
        }
    }
}
