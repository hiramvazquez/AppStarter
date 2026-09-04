import AppFoundation
import ImageIO

#if canImport(SwiftUI)
import SwiftUI

/// `ScreenContainer` bound to `UploadsViewModel` (PRD-APP-02): captures a photo via `any
/// CameraCapturing` and uploads it to `POST /products/add` with a real progress bar
/// (`activity()`, `.inline`). Never references `UploadsLogic`/`UploadsService`/
/// `CameraKit`/`APIService` directly.
///
/// `platformImage(from:)` decodes through `ImageIO`'s `CGImageSource`, not `UIImage(data:)`
/// — `.archlint.yml` (R13) forbids any import matching the glob `*Kit`, which (a real
/// friction, PRD-APP-02) catches `UIKit` itself, not just this project's own `CameraKit`/
/// future `*Kit` capability targets. `ImageIO`/`CoreGraphics` sidestep it entirely and work
/// identically on iOS/macOS.
public struct UploadsView: View {
    @State private var viewModel: UploadsViewModel

    public init(viewModel: UploadsViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    public var body: some View {
        ScreenContainer(viewModel) { send in
            Form {
                Section("Foto") {
                    if let data = viewModel.capturedPhotoData, let image = platformImage(from: data) {
                        image
                            .resizable()
                            .scaledToFit()
                            .frame(height: 160)
                            .accessibilityIdentifier("uploads.photo.preview")
                    } else {
                        Text("Ninguna foto todavía.")
                            .foregroundStyle(.secondary)
                    }
                    Button("Tomar foto") { send(.capturePhoto) }
                        .accessibilityIdentifier("uploads.capture")
                }

                Section("Producto") {
                    TextField(
                        "Título",
                        text: Binding(get: { viewModel.title }, set: { viewModel.title = $0 })
                    )
                    .accessibilityIdentifier("uploads.title")
                }

                Section {
                    if viewModel.isPerformingActivity {
                        VStack(alignment: .leading) {
                            ProgressView(value: viewModel.progress)
                                .accessibilityIdentifier("uploads.progress")
                            Text("\(Int(viewModel.progress * 100))%")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        Button("Subir") { send(.upload) }
                            .disabled(viewModel.capturedPhotoData == nil)
                            .accessibilityIdentifier("uploads.submit")
                    }
                }

                if let product = viewModel.uploadedProduct {
                    Section("Resultado") {
                        Text("Producto #\(product.id) — \(product.title)")
                            .accessibilityIdentifier("uploads.result")
                    }
                }
            }
            .task { send(.appear) }
        }
        .navigationTitle("Subir foto")
    }

    private func platformImage(from data: Data) -> Image? {
        guard
            let source = CGImageSourceCreateWithData(data as CFData, nil),
            let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil)
        else { return nil }
        return Image(decorative: cgImage, scale: 1, orientation: .up)
    }
}
#endif

// MARK: - Preview: a stub, never used outside DEBUG

#if canImport(SwiftUI) && DEBUG
private final class UploadsPreviewLogic: UploadsLogicProtocol {
    func capturePhoto() async throws -> Data { Data() }
    func upload(
        title: String,
        photoData: Data,
        progress: @escaping @Sendable (Double) -> Void
    ) async throws -> UploadedProduct {
        UploadedProduct(id: 101, title: title)
    }
}

#Preview {
    NavigationStack {
        UploadsView(viewModel: UploadsViewModel(logic: UploadsPreviewLogic()))
    }
}
#endif
