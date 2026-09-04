import Foundation

/// Every way capturing a photo can fail — never a raw `UIImagePickerController`/AVFoundation
/// error, which stops at `CameraKit`.
public enum CameraCaptureError: Error, Equatable {
    case cancelled
    case noPresenter
    case encodingFailed
}

/// Capability contract for capturing a photo, implemented by the `CameraKit` target
/// (`CameraKitCapture`: `SimulatedCamera` on the Simulator/DEBUG, a real
/// `UIImagePickerController` flow on device). Features depend on THIS protocol, never on
/// `CameraKit` directly — the concrete type is wired once, in `App/AppModule.swift`;
/// `.archlint.yml` (R13) blocks a feature from importing `CameraKit`.
///
/// Separate from `CameraProviding` (this file's sibling): that one only answers "is a
/// camera available" — this one does the actual capture. `Uploads` (PRD-APP-02) is the
/// first, and today only, consumer.
public protocol CameraCapturing: Sendable {
    /// Captures (or, on the Simulator, simulates) a photo and returns its encoded bytes
    /// (JPEG/PNG) — never a platform-specific image type, so `Domain` stays
    /// Foundation-only and every feature gets back something it can upload as-is.
    func capturePhoto() async throws -> Data
}
