import CoreNetworking
import Foundation

/// A `RequestInterceptor` of this app's own (PRD-APP-02, Fase 2): adds `X-Client` to every
/// request it sees and counts attempts by `RequestContext`, appending a human-readable
/// line per `willSend`/`didReceive`/`didFail` to `lines` — what the Diagnostics screen
/// renders as its captured log.
///
/// `LoggingInterceptor` (`CoreNetworking`) is wired into the SAME pipeline
/// (`DiagnosticsService`'s retry-demo `APIService`) and genuinely logs every attempt —
/// but through `os.Logger`, which this app can't read back in-process without
/// `OSLogStore`/extra entitlements (not guaranteed available in every environment this
/// runs in). This interceptor is the honest way to show an equivalent, in-app-readable
/// log on screen without pretending to capture `LoggingInterceptor`'s own output.
///
/// `actor`, like `RecordingInterceptor` (`CoreNetworkingTestSupport`) — `APIService` can
/// call an interceptor from more than one attempt, so recording needs real
/// synchronization.
public actor RequestCounterInterceptor: RequestInterceptor {
    public private(set) var requestCount = 0
    public private(set) var lines: [String] = []

    public init() {}

    public func reset() {
        requestCount = 0
        lines = []
    }

    public func willSend(_ request: URLRequest, context: RequestContext) async throws(APIError) -> URLRequest {
        requestCount += 1
        lines.append("→ intento \(context.attempt): \(request.httpMethod ?? "GET") \(request.url?.path ?? "-")")
        var modified = request
        modified.setValue("AppStarter-Diagnostics", forHTTPHeaderField: "X-Client")
        return modified
    }

    public func didReceive(_ response: HTTPURLResponse, data: Data, context: RequestContext) async {
        lines.append("← intento \(context.attempt): \(response.statusCode)")
    }

    public func didFail(_ error: APIError, context: RequestContext) async {
        lines.append("✗ intento \(context.attempt): \(error.code.rawValue)")
    }
}
