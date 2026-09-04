import AppFoundationTestSupport
import Foundation
import Networking

/// Spy that substitutes `SessionExpiring` in pipeline-level tests — records whether the
/// "session can no longer be recovered" callback fired, without touching the real
/// `AppSessionState`/`Coordinator`. Shared the same way as `SessionStoreSpy` — see its
/// doc comment for why this lives in `PlatformTestSupport`.
public final class SessionExpiringSpy: SessionExpiring, @unchecked Sendable {
    // Nonisolated on purpose: without an explicit deinit the compiler synthesizes an isolated
    // one that goes through a back-deploy shim on OS versions older than the toolchain's
    // runtime; two of those nested aborted on iOS 26.2 (AppFoundation 1.2.2 release notes,
    // `docs/repros/isolated-deinit-backdeploy.md`). Nothing to clean up here.
    deinit {}

    public let calls = SpyRecorder<Void>()

    public init() {}

    public func sessionDidExpire() async {
        await calls.record()
    }
}
