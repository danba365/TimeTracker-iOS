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
        let file = folder.appendingPathComponent(attachment.fileName)
        if FileManager.default.fileExists(atPath: file.path) { return file }

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

    /// Best effort: remove a task's stored files before the task is deleted.
    func deleteFiles(forTask taskId: String) async {
        do {
            let paths = try await attachments(for: taskId).map(\.storagePath)
            guard !paths.isEmpty,
                  let url = URL(string: "\(Config.supabaseURL)/storage/v1/object/\(bucket)") else { return }
            _ = try await SupabaseRequest.send(url, method: "DELETE", json: ["prefixes": paths])
            taskIdsWithAttachments.remove(taskId)
        } catch {
            print("⚠️ Could not remove attachment files: \(error)")
        }
    }
}
