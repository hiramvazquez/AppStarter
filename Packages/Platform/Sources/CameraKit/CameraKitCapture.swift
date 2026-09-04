import Domain
import Foundation

#if canImport(UIKit)
import UIKit
#endif

/// The `CameraCapturing` this app runs with (PRD-APP-02, `Uploads`): a deterministic
/// simulated capture on the Simulator/DEBUG (no user interaction — safe for XCUITests),
/// a real `UIImagePickerController` flow on device otherwise.
public struct CameraKitCapture: CameraCapturing {
    public init() {}

    public func capturePhoto() async throws -> Data {
        #if targetEnvironment(simulator) || !os(iOS)
        return try await SimulatedCamera().capturePhoto()
        #else
        return try await DeviceCameraCapture().capturePhoto()
        #endif
    }
}

/// Always available, deterministic, and instant — what every DEBUG build and every
/// Simulator run uses (real device camera hardware doesn't exist there). Renders a small
/// solid-color square instead of shipping a real bundled image asset — no
/// `Resources/`/`Package.swift` resource wiring needed, and it is exactly as good a
/// stand-in for "a photo the user took" as a static asset would be for this showcase.
public struct SimulatedCamera: CameraCapturing {
    public init() {}

    public func capturePhoto() async throws -> Data {
        #if canImport(UIKit)
        let size = CGSize(width: 256, height: 256)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { _ in
            UIColor.systemTeal.setFill()
            UIRectFill(CGRect(origin: .zero, size: size))
        }
        guard let data = image.pngData() else { throw CameraCaptureError.encodingFailed }
        return data
        #else
        // macOS build of this package (Platform's own `swift test`/`swift build` target
        // list, PRD-APP-02 Fase 1): UIKit doesn't exist — a minimal, valid PNG signature
        // is enough to keep this platform compiling; nothing on macOS ever calls this.
        return Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])
        #endif
    }
}

#if os(iOS)
/// The real device flow: presents `UIImagePickerController` over the key window's root
/// view controller — `.camera` when hardware allows it, `.photoLibrary` otherwise (the
/// Simulator has no `.camera` source, but `CameraKitCapture` never reaches this type
/// there — see its `#if` above).
@MainActor
public struct DeviceCameraCapture: CameraCapturing {
    public init() {}

    public func capturePhoto() async throws -> Data {
        let sourceType: UIImagePickerController.SourceType =
            UIImagePickerController.isSourceTypeAvailable(.camera) ? .camera : .photoLibrary
        return try await ImagePickerCoordinator().present(sourceType: sourceType)
    }
}

/// `NSObject`-based delegate the picker needs — bridges its callback-based API to a single
/// `async` call via `CheckedContinuation`. Not `Sendable`: it is only ever touched on the
/// main actor (`@MainActor`, like `DeviceCameraCapture` itself), the same isolation
/// `UIImagePickerControllerDelegate` callbacks always run on.
@MainActor
private final class ImagePickerCoordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    private var continuation: CheckedContinuation<Data, any Error>?

    func present(sourceType: UIImagePickerController.SourceType) async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            guard
                let root = UIApplication.shared.connectedScenes
                    .compactMap({ ($0 as? UIWindowScene)?.keyWindow })
                    .first?
                    .rootViewController
            else {
                continuation.resume(throwing: CameraCaptureError.noPresenter)
                return
            }
            let picker = UIImagePickerController()
            picker.sourceType = sourceType
            picker.delegate = self
            root.present(picker, animated: true)
        }
    }

    func imagePickerController(
        _ picker: UIImagePickerController,
        didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
    ) {
        picker.dismiss(animated: true)
        guard let image = info[.originalImage] as? UIImage, let data = image.jpegData(compressionQuality: 0.8) else {
            continuation?.resume(throwing: CameraCaptureError.encodingFailed)
            continuation = nil
            return
        }
        continuation?.resume(returning: data)
        continuation = nil
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true)
        continuation?.resume(throwing: CameraCaptureError.cancelled)
        continuation = nil
    }
}
#endif
