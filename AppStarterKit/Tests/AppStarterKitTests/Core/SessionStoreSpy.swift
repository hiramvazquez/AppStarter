import AppFoundationTestSupport
import Foundation

@testable import AppStarterKit

/// Spy/stub that substitutes `SessionStoring` across every feature's `Logic` tests —
/// never a real `UserDefaultsSessionStore` in a unit test.
actor SessionStoreSpy: SessionStoring {
    let savedSessions = SpyRecorder<StoredSession>()
    private(set) var invalidateCallCount = 0
    var sessionToReturn: StoredSession?

    init(sessionToReturn: StoredSession? = nil) {
        self.sessionToReturn = sessionToReturn
    }

    func currentAccessToken() async -> String? {
        sessionToReturn?.accessToken
    }

    func currentSession() async -> StoredSession? {
        sessionToReturn
    }

    func save(_ session: StoredSession) async {
        sessionToReturn = session
        await savedSessions.record(session)
    }

    func invalidate() async {
        sessionToReturn = nil
        invalidateCallCount += 1
    }
}
