import AppFoundationTestSupport
import Foundation

@testable import AppStarterKit

/// Spy that substitutes `SessionExpiring` in pipeline-level tests — records whether the
/// "session can no longer be recovered" callback fired, without touching the real
/// `AppSessionState`/`Coordinator`.
final class SessionExpiringSpy: SessionExpiring, @unchecked Sendable {
    let calls = SpyRecorder<Void>()

    func sessionDidExpire() async {
        await calls.record()
    }
}
