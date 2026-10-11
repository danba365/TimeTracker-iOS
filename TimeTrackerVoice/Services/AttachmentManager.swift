import Foundation

/// Task attachments (read-only on iOS): list, paperclip index, signed download with a local cache.
@MainActor
final class AttachmentManager: ObservableObject {
    static let shared = AttachmentManager()

    enum AttachmentError: Error { case unavailable, failed }

    @Published private(set) var taskIdsWithAttachments: Set<String> = []

    private let bucket = "task-attachments"
    private let cacheRoot: URL = FileManager.default
        .urls(for: .cachesDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("attachments", isDirectory: true)

    private init() {}

    /// Which tasks have files (drives the paperclip in the task lists).
    func refreshIndex() async {
        guard let url = URL(string: "\(Config.supabaseURL)/rest/v1/task_attachments?select=task_id") else { return }
        do {
            let (data, http) = try await SupabaseRequest.send(url)
            guard http.statusCode == 200 else { return }
            let rows = try JSONDecoder().decode([[String: String]].self, from: data)
            taskIdsWithAttachments = Set(rows.compactMap { $0["task_id"] })
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

    /// Clear in-memory index and cached files (sign-out).
    func reset() {
        taskIdsWithAttachments = []
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
