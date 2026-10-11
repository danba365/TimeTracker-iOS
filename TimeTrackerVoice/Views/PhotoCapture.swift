import SwiftUI
import UIKit

/// A photo picked or taken in the app, waiting to be uploaded.
struct PendingPhoto: Identifiable {
    let id = UUID()
    let jpeg: Data
    let thumbnail: UIImage

    /// Downscales to at most 2048 px on the long side and encodes as JPEG
    /// (well under the 10 MB storage limit). Returns nil for unreadable data.
    static func make(from image: UIImage) -> PendingPhoto? {
        let full = image.resized(maxSide: 2048)
        guard let jpeg = full.jpegData(compressionQuality: 0.8) else { return nil }
        return PendingPhoto(jpeg: jpeg, thumbnail: full.resized(maxSide: 240))
    }

    static func make(from data: Data) -> PendingPhoto? {
        UIImage(data: data).flatMap(make(from:))
    }
}

private extension UIImage {
    /// Redraws upright (camera photos carry an orientation flag) and no larger than `maxSide`.
    func resized(maxSide: CGFloat) -> UIImage {
        let longest = max(size.width, size.height)
        let scale = longest > maxSide ? maxSide / longest : 1
        let target = CGSize(width: (size.width * scale).rounded(), height: (size.height * scale).rounded())
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        return UIGraphicsImageRenderer(size: target, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: target))
        }
    }
}

/// The system camera, returning the captured photo.
struct CameraPicker: UIViewControllerRepresentable {
    let onImage: (UIImage) -> Void
    let onDismiss: () -> Void

    static var isAvailable: Bool { UIImagePickerController.isSourceTypeAvailable(.camera) }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ picker: UIImagePickerController, context: Context) {}

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraPicker
        init(_ parent: CameraPicker) { self.parent = parent }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            if let image = info[.originalImage] as? UIImage { parent.onImage(image) }
            parent.onDismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.onDismiss()
        }
    }
}

/// Square thumbnail of a stored image attachment (downloaded through the attachment cache).
struct AttachmentThumbnail: View {
    let attachment: TaskAttachment
    @State private var image: UIImage?
    @State private var failed = false

    var body: some View {
        ZStack {
            Color(.secondarySystemBackground)
            if let image {
                Image(uiImage: image).resizable().scaledToFill()
            } else if failed {
                Image(systemName: "photo").foregroundColor(.secondary)
            } else {
                ProgressView()
            }
        }
        .task(id: attachment.id) {
            guard let file = try? await AttachmentManager.shared.localFile(for: attachment),
                  let loaded = UIImage(contentsOfFile: file.path) else {
                failed = true
                return
            }
            image = loaded
        }
    }
}
