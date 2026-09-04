import Domain
import Foundation

/// Stub implementation of `CameraProviding` — compiles out of the box, `isAvailable()`
/// always answers `false`. Replace the body with the real Camera integration
/// (AVFoundation/CoreLocation/whatever this capability needs); `.archlint.yml` restricts
/// this target to `[Foundation, Domain]` plus the system frameworks you add here — it
/// never imports a feature, an adapter, or another Kit (R13).
public struct CameraKitProvider: CameraProviding {
    public init() {}

    public func isAvailable() -> Bool {
        false
    }
}
