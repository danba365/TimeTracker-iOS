import SwiftUI
import QuickLook

/// Full-screen Quick Look preview (PDF pages / zoomable image) with the system Share button.
struct AttachmentPreview: UIViewControllerRepresentable {
    let fileURL: URL

    func makeCoordinator() -> Coordinator { Coordinator(fileURL: fileURL) }

    func makeUIViewController(context: Context) -> UINavigationController {
        let controller = QLPreviewController()
        controller.dataSource = context.coordinator
        return UINavigationController(rootViewController: controller)
    }

    func updateUIViewController(_ controller: UINavigationController, context: Context) {}

    final class Coordinator: NSObject, QLPreviewControllerDataSource {
        let fileURL: URL
        init(fileURL: URL) { self.fileURL = fileURL }
        func numberOfPreviewItems(in controller: QLPreviewController) -> Int { 1 }
        func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
            fileURL as NSURL
        }
    }
}

/// Identifiable wrapper so a URL can drive `.fullScreenCover(item:)`.
struct PreviewFile: Identifiable {
    let url: URL
    var id: String { url.path }
}
