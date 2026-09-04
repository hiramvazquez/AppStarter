import CoreNetworking
import CoreNetworkingTestSupport
import Domain
import Foundation
import PlatformTestSupport
import Testing

@testable import Networking

/// `makeAuthenticatedAPIService` tested against the REAL pipeline —
/// `InMemoryTransport`/`ManualClock`, never `Task.sleep` — proving the 401 → refresh →
/// retry flow this app wires up actually works, without touching DummyJSON. The
/// integration test (`Packages/Features`, `AuthIntegrationTests`) proves the same flow
/// against the real API.
///
/// Exercises the pipeline with `PingRequest`, a minimal `BaseRequest` local to this file
/// — `Networking` (this target) can't reach into any `*Feature`'s own request DTOs
/// (`GetMeRequest` and friends stay `Profile Feature`-internal, M2), so the test needs
/// its own stand-in endpoint instead of reusing one.
@Suite("Authenticated APIService pipeline")
@MainActor
struct NetworkingWiringTests {
    private static let baseURL = URL(string: "https://unit.test")!
    private static let pingURL = baseURL.appendingPathComponent("ping")
    private static let refreshURL = baseURL.appendingPathComponent("auth/refresh")

    private static let pingBody = Data(#"{"status":true}"#.utf8)
    private static let refreshBody = Data(
        """
        {"accessToken":"new-access","refreshToken":"new-refresh"}
        """
        .utf8
    )

    private struct PingRequest: BaseRequest {
        struct Response: Decodable, Sendable { let status: Bool }
        let path = "/ping"
        let method = HTTPMethod.get
    }

    @Test("A 401 triggers exactly one refresh, then the original request is retried and succeeds")
    func refreshOnUnauthorizedThenRetries() async throws {
        let transport = InMemoryTransport()
        await transport.register(
            InMemoryTransport.Exchange(
                method: .get,
                url: Self.pingURL,
                responses: [.response(status: 401), .response(status: 200, body: Self.pingBody)]
            )
        )
        await transport.register(
            InMemoryTransport.Exchange(
                method: .post,
                url: Self.refreshURL,
                response: .response(status: 200, body: Self.refreshBody)
            )
        )

        let sessionStore = SessionStoreSpy(
            sessionToReturn: StoredSession(accessToken: "old-access", refreshToken: "old-refresh", userID: 1)
        )
        let expiring = SessionExpiringSpy()
        let refreshLog = RefreshActivityLog()
        let configuration = NetworkingConfiguration(baseURL: Self.baseURL)
        let authService = AuthService(api: APIService(configuration: configuration, transport: transport))

        // `TokenRefreshRetrier`'s `.retry` decision still goes through
        // `APIService`'s own backoff delay (`RetryPolicy.jitteredDelay`) before the
        // retried request goes out — this `ManualClock` is what lets the test drive
        // that delay instead of actually waiting on it (Retry.md).
        let clock = ManualClock()
        let api = makeAuthenticatedAPIService(
            configuration: configuration,
            transport: transport,
            authService: authService,
            sessionStore: sessionStore,
            sessionExpiring: expiring,
            refreshLog: refreshLog,
            refreshExpiresInMinutes: 1,
            clock: clock
        )

        let task = Task { try await api.execute(PingRequest()) }
        await clock.waitUntilSleeping()
        clock.advance(by: .seconds(1))
        let response = try await task.value

        #expect(response.status)
        #expect(await sessionStore.savedSessions.count == 1)
        #expect(await sessionStore.currentSession()?.accessToken == "new-access")
        #expect(refreshLog.refreshCount == 1)
        #expect(await expiring.calls.wasCalled == false)
    }

    @Test("When the refresh itself fails, the session is invalidated and SessionExpiring fires — no extra request")
    func failedRefreshInvalidatesSessionAndNotifiesExpiry() async {
        let transport = InMemoryTransport()
        await transport.register(
            InMemoryTransport.Exchange(method: .get, url: Self.pingURL, response: .response(status: 401))
        )
        await transport.register(
            InMemoryTransport.Exchange(method: .post, url: Self.refreshURL, response: .response(status: 403))
        )

        let sessionStore = SessionStoreSpy(
            sessionToReturn: StoredSession(accessToken: "old-access", refreshToken: "old-refresh", userID: 1)
        )
        let expiring = SessionExpiringSpy()
        let refreshLog = RefreshActivityLog()
        let configuration = NetworkingConfiguration(baseURL: Self.baseURL)
        let authService = AuthService(api: APIService(configuration: configuration, transport: transport))

        let api = makeAuthenticatedAPIService(
            configuration: configuration,
            transport: transport,
            authService: authService,
            sessionStore: sessionStore,
            sessionExpiring: expiring,
            refreshLog: refreshLog,
            refreshExpiresInMinutes: 1,
            clock: ManualClock()
        )

        await #expect(throws: (any Error).self) {
            try await api.execute(PingRequest())
        }

        #expect(await sessionStore.currentSession() == nil)
        #expect(await expiring.calls.wasCalled)
        #expect(refreshLog.refreshCount == 0)
    }
}
