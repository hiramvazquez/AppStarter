import CoreNetworking
import CoreNetworkingTestSupport
import Foundation

// MARK: - The requests (M2: only this file ever sees them)

private struct NotFoundProductRequest: BaseRequest {
    let path = "/products/999999"
    let method = HTTPMethod.get
}

private struct MeRequest: BaseRequest {
    let path = "/auth/me"
    let method = HTTPMethod.get
}

/// A deliberately-impossible client timeout (1 ms): any real round trip — DummyJSON
/// included — takes longer, so `URLSessionTransport`'s `URLSession` always fails it with
/// `URLError.timedOut` before a response arrives.
private struct ShortTimeoutRequest: BaseRequest {
    let path = "/products/1"
    let method = HTTPMethod.get
    let timeout: Duration = .milliseconds(1)
}

/// Same endpoint as `ShortTimeoutRequest`/the app's own `ProductDetail`, decoded into a
/// type the response can never satisfy — `decodeBody`'s failure mode, not a malformed
/// server response.
private struct MismatchedShapeRequest: BaseRequest {
    struct Response: Decodable, Sendable { let thisKeyDoesNotExist: Int }
    let path = "/products/1"
    let method = HTTPMethod.get
}

private struct UnreachablePingRequest: BaseRequest {
    let path = "/"
    let method = HTTPMethod.get
}

private struct RetryDemoRequest: BaseRequest {
    let path = "/diagnostics/retry-demo"
    let method = HTTPMethod.get
}

private struct SlowDelayRequest: BaseRequest {
    let path = "/products"
    let method = HTTPMethod.get
    var queryItems: [URLQueryItem] { [URLQueryItem(name: "delay", value: "3000")] }
}

// MARK: - The service

/// One `Service` — but, unlike every other feature's ("un Service, una llamada a API"),
/// this one is genuinely about MULTIPLE deliberately-misconfigured `APIServiceProtocol`
/// instances: that IS what Diagnostics demonstrates (PRD-APP-02, generated with
/// `--no-service`, completed by hand as its own minimal Service over `APIServiceProtocol`).
/// `DiagnosticsLogic` never touches `APIError`/`BaseRequest` itself — this is still the
/// only file that does.
public protocol DiagnosticsServicing: Sendable {
    func run404() async -> DiagnosticsOutcome
    func run401() async -> DiagnosticsOutcome
    func runTimeout() async -> DiagnosticsOutcome
    func runInvalidJSON() async -> DiagnosticsOutcome
    func runUnreachable() async -> DiagnosticsOutcome
    func runRetry5xx() async -> DiagnosticsOutcome
    func runSlow() async -> DiagnosticsOutcome
    func capturedLogLines() async -> [String]
}

public final class DiagnosticsService: DiagnosticsServicing, @unchecked Sendable {
    /// The app's own authenticated `APIServiceProtocol` (`NetworkingModule`) — reused
    /// as-is for the experiments that don't need a DIFFERENT pipeline (404, timeout,
    /// invalid JSON, the cancelable slow request): under `-UITestOffline` it is already
    /// the offline `InMemoryTransport`, exactly like every other feature.
    private let authenticatedAPI: any APIServiceProtocol
    private let unauthenticatedAPI: any APIServiceProtocol
    private let unreachableAPI: any APIServiceProtocol
    private let retryAPI: any APIServiceProtocol
    private let retryTransport: InMemoryTransport
    private let retryURL: URL
    private let retryCounter: RequestCounterInterceptor

    /// - Parameters:
    ///   - baseURL: DummyJSON's base URL, for the unauthenticated (401) pipeline.
    ///   - authenticatedAPI: The app's own authenticated `APIServiceProtocol` — resolved
    ///     from the `Container`, never constructed here.
    ///   - offlineTransport: `-UITestOffline`'s shared `InMemoryTransport`, when set —
    ///     used for the 401/unreachable pipelines, which this Service otherwise builds
    ///     its OWN real `URLSessionTransport` for (they deliberately differ from the
    ///     app's authenticated one). `nil` (production) uses `URLSessionTransport`.
    public init(baseURL: URL, authenticatedAPI: any APIServiceProtocol, offlineTransport: (any HTTPTransport)? = nil) {
        self.authenticatedAPI = authenticatedAPI

        let configuration = NetworkingConfiguration(baseURL: baseURL)
        self.unauthenticatedAPI = APIService(
            configuration: configuration,
            transport: offlineTransport ?? URLSessionTransport()
        )

        let unreachableConfiguration = NetworkingConfiguration(
            baseURL: URL(string: "https://unreachable.invalid") ?? baseURL
        )
        self.unreachableAPI = APIService(
            configuration: unreachableConfiguration,
            transport: offlineTransport ?? URLSessionTransport()
        )

        let counter = RequestCounterInterceptor()
        self.retryCounter = counter
        // No fixture registered yet (`runRetry5xx()` does that, lazily) — registering it
        // here would need `await`, and this `init` runs synchronously on whichever actor
        // resolves `DiagnosticsServicing` from the `Container` (the main actor, during a
        // SwiftUI navigation to `.diagnostics`); bridging that with a blocking
        // `DispatchSemaphore` (`OfflineFixtures.makeTransport()`'s own pattern, safe ONLY
        // at app launch before anything else needs the main thread) stalled real
        // navigation for ~60s here — reproduced with `DiagnosticsUITests` against the
        // Simulator. See `docs/INFORME-MULTI.md`.
        let transport = InMemoryTransport()
        self.retryTransport = transport
        self.retryURL = baseURL.appendingPathComponent("diagnostics/retry-demo")
        self.retryAPI = APIService(
            configuration: configuration,
            transport: transport,
            retryPolicy: RetryPolicy(maxAttempts: 3, initialDelay: .milliseconds(50), maxDelay: .milliseconds(200)),
            interceptors: [LoggingInterceptor(), counter]
        )
    }

    // MARK: - Experiments

    public func run404() async -> DiagnosticsOutcome {
        await Self.outcome { try await authenticatedAPI.execute(NotFoundProductRequest()) }
    }

    public func run401() async -> DiagnosticsOutcome {
        await Self.outcome { try await unauthenticatedAPI.execute(MeRequest()) }
    }

    public func runTimeout() async -> DiagnosticsOutcome {
        await Self.outcome { try await authenticatedAPI.execute(ShortTimeoutRequest()) }
    }

    public func runInvalidJSON() async -> DiagnosticsOutcome {
        await Self.outcome { try await authenticatedAPI.execute(MismatchedShapeRequest()) }
    }

    public func runUnreachable() async -> DiagnosticsOutcome {
        await Self.outcome { try await unreachableAPI.execute(UnreachablePingRequest()) }
    }

    public func runRetry5xx() async -> DiagnosticsOutcome {
        // Registered fresh on every run (idempotent, cheap — `InMemoryTransport.register`
        // just overwrites and resets its cursor): this also makes the experiment properly
        // repeatable, unlike a one-shot registration that only the FIRST tap would see
        // start from attempt 1.
        await retryTransport.register(
            InMemoryTransport.Exchange(
                url: retryURL,
                responses: [
                    .response(status: 503),
                    .response(status: 503),
                    .response(status: 200, body: Data("{}".utf8))
                ]
            )
        )
        await retryCounter.reset()
        let outcome = await Self.outcome { try await retryAPI.execute(RetryDemoRequest()) }
        let attempts = await retryCounter.requestCount
        return DiagnosticsOutcome(
            succeeded: outcome.succeeded,
            category: outcome.category,
            code: outcome.code,
            requestSummary: outcome.requestSummary,
            responseSummary: outcome.responseSummary,
            attempts: attempts,
            wasCancelled: outcome.wasCancelled
        )
    }

    public func runSlow() async -> DiagnosticsOutcome {
        await Self.outcome { try await authenticatedAPI.execute(SlowDelayRequest(), as: Empty.self) }
    }

    public func capturedLogLines() async -> [String] {
        await retryCounter.lines
    }

    // MARK: - Outcome mapping

    private static func outcome<Response: Sendable>(_ work: () async throws -> Response) async -> DiagnosticsOutcome {
        do {
            _ = try await work()
            return DiagnosticsOutcome(
                succeeded: true,
                category: "success",
                code: "-",
                requestSummary: "-",
                responseSummary: "-"
            )
        } catch let error as APIError {
            return DiagnosticsOutcome(
                succeeded: false,
                category: String(describing: error.category),
                code: error.code.rawValue,
                requestSummary: error.request.map { "\($0.method.rawValue) \($0.url?.absoluteString ?? "-")" } ?? "-",
                responseSummary: error.response.map { "\($0.statusCode) — \($0.body.count) bytes" } ?? "-",
                wasCancelled: error.isCancellation
            )
        } catch {
            return DiagnosticsOutcome(
                succeeded: false,
                category: "unknown",
                code: "unexpected",
                requestSummary: "-",
                responseSummary: "-"
            )
        }
    }
}
