import Foundation

/// Capability contract for Camera, implemented by the `CameraKit` target
/// (`CameraKitProvider`). Features depend on THIS protocol, never on `CameraKit`
/// directly — the concrete type is wired once, in `App/AppModule.swift` (the composition
/// root); `.archlint.yml` (R13) blocks a feature from importing `CameraKit`.
public protocol CameraProviding: Sendable {
    /// Whether this capability is currently available on the device.
    func isAvailable() -> Bool
}
