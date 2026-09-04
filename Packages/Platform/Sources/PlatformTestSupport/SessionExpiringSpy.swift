import AppFoundationTestSupport
import Foundation
import Networking

/// Spy that substitutes `SessionExpiring` in pipeline-level tests — records whether the
/// "session can no longer be recovered" callback fired, without touching the real
/// `AppSessionState`/`Coordinator`. Shared the same way as `SessionStoreSpy` — see its
/// doc comment for why this lives in `PlatformTestSupport`.
public final class SessionExpiringSpy: SessionExpiring, @unchecked Sendable {
    public let calls = SpyRecorder<Void>()

    public init() {}

    public func sessionDidExpire() async {
        await calls.record()
    }
}
