import AppFoundationTestSupport
import Domain
import Foundation

/// Spy/stub that substitutes `SessionStoring` across every feature's `Logic` tests —
/// never a real `UserDefaultsSessionStore` in a unit test. Shared by `LoginFeatureTests`,
/// `ProfileFeatureTests`, `NetworkingTests` and the integration suite — exactly like the
/// production `UserDefaultsSessionStore` is a single, app-wide implementation every
/// authenticated feature resolves the same way.
///
/// `PlatformTestSupport` (this target) is a regular library product, not a `.testTarget`
/// — SwiftPM test targets aren't importable across packages, and every `*FeatureTests`
/// target that needs this spy lives in the separate `Packages/Features` package. Mirrors
/// `AppFoundationTestSupport`'s own shape (a production-adjacent, test-only product).
public actor SessionStoreSpy: SessionStoring {
    public let savedSessions = SpyRecorder<StoredSession>()
    public private(set) var invalidateCallCount = 0
    public var sessionToReturn: StoredSession?

    public init(sessionToReturn: StoredSession? = nil) {
        self.sessionToReturn = sessionToReturn
    }

    public func currentAccessToken() async -> String? {
        sessionToReturn?.accessToken
    }

    public func currentSession() async -> StoredSession? {
        sessionToReturn
    }

    public func save(_ session: StoredSession) async {
        sessionToReturn = session
        await savedSessions.record(session)
    }

    public func invalidate() async {
        sessionToReturn = nil
        invalidateCallCount += 1
    }
}
