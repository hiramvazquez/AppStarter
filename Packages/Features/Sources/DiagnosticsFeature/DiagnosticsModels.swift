import AppFoundation
import Foundation

// MARK: - Experiments

/// One networking capability of `CoreNetworking` Diagnostics demonstrates against a real
/// (or, under `-UITestOffline`, fixture) DummyJSON call. `CaseIterable` drives the list —
/// adding a row here is the only step to add a new experiment to the screen.
public enum DiagnosticsExperiment: String, CaseIterable, Sendable, Identifiable {
    case notFound404
    case unauthorized401
    case timeout
    case invalidJSON
    case unreachableHost
    case retry5xx
    case slowCancelable

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .notFound404: return "404 — producto inexistente"
        case .unauthorized401: return "401 — sin token"
        case .timeout: return "Timeout de 1 ms"
        case .invalidJSON: return "JSON inválido (decodeBody)"
        case .unreachableHost: return "Host inalcanzable"
        case .retry5xx: return "5xx con reintentos"
        case .slowCancelable: return "Petición lenta cancelable"
        }
    }

    public var subtitle: String {
        switch self {
        case .notFound404: return "GET /products/999999"
        case .unauthorized401: return "GET /auth/me sin BearerTokenInterceptor"
        case .timeout: return "GET /products/1 con timeout de 1 ms"
        case .invalidJSON: return "GET /products/1 decodificado en un tipo incompatible"
        case .unreachableHost: return "GET https://unreachable.invalid"
        case .retry5xx: return "Fixture: 503, 503, 200 — RequestCounterInterceptor"
        case .slowCancelable: return "GET /products?delay=3000 — cancelable con inFlightLoad"
        }
    }
}

// MARK: - Outcome (Service → Logic, still network-shaped — never reaches the ViewModel)

/// What `DiagnosticsServicing` hands back: `APIError`'s shape projected into plain,
/// `Sendable` strings — never `APIError`/`RequestSummary`/`ResponseSummary` themselves
/// (M2): those stop at this Service, same as any other DTO.
public struct DiagnosticsOutcome: Sendable, Equatable {
    public let succeeded: Bool
    /// `APIError.Category`, stringified (`"notFound"`, `"unauthorized"`, `"timeout"`…) —
    /// or `"success"` when the call actually succeeded.
    public let category: String
    /// `APIError.Code.rawValue`, or `"-"` on success.
    public let code: String
    public let requestSummary: String
    public let responseSummary: String
    /// Total requests the pipeline sent for this experiment (`RequestCounterInterceptor`,
    /// retry5xx only) — `1` for every other experiment.
    public let attempts: Int
    public let wasCancelled: Bool

    public init(
        succeeded: Bool,
        category: String,
        code: String,
        requestSummary: String,
        responseSummary: String,
        attempts: Int = 1,
        wasCancelled: Bool = false
    ) {
        self.succeeded = succeeded
        self.category = category
        self.code = code
        self.requestSummary = requestSummary
        self.responseSummary = responseSummary
        self.attempts = attempts
        self.wasCancelled = wasCancelled
    }
}

// MARK: - Domain errors (M1)

/// The Logic's own mapping of `DiagnosticsOutcome.category` — the DomainError the screen
/// shows next to each experiment's raw category/code, exactly the "APIError → DomainError"
/// boundary every other feature's Logic already enforces, made visible here on purpose.
public enum DiagnosticsError: DomainError, Equatable {
    case notFound
    case unauthorized
    case timeout
    case decoding
    case unreachable
    case server
    case cancelled
    case unknown

    public var isRetryable: Bool {
        switch self {
        case .server, .timeout: return true
        case .notFound, .unauthorized, .decoding, .unreachable, .cancelled, .unknown: return false
        }
    }

    public var screenError: ScreenError {
        switch self {
        case .notFound: return ScreenError(title: "No encontrado", message: "El recurso no existe (404).")
        case .unauthorized: return ScreenError(title: "No autorizado", message: "Falta el token (401).")
        case .timeout: return ScreenError(title: "Timeout", message: "El servidor no respondió a tiempo.")
        case .decoding:
            return ScreenError(title: "JSON inválido", message: "La respuesta no coincide con el tipo esperado.")
        case .unreachable:
            return ScreenError(title: "Host inalcanzable", message: "No se pudo conectar con el servidor.")
        case .server: return ScreenError(title: "Error del servidor", message: "Inténtalo de nuevo.")
        case .cancelled: return ScreenError(title: "Cancelado", message: "La operación se canceló.")
        case .unknown: return ScreenError(title: "Algo salió mal", message: "Inténtalo de nuevo.")
        }
    }

    /// Maps `DiagnosticsOutcome.category` (an `APIError.Category`, stringified by the
    /// Service) to a `DiagnosticsError`. The one place this screen translates network
    /// vocabulary into domain vocabulary (M1) — everything above this reads `screenError`/
    /// `isRetryable`, never the raw category string.
    public static func from(category: String) -> DiagnosticsError {
        switch category {
        case "notFound": return .notFound
        case "unauthorized": return .unauthorized
        case "timeout": return .timeout
        case "decoding": return .decoding
        case "unreachable": return .unreachable
        case "server": return .server
        case "cancelled": return .cancelled
        default: return .unknown
        }
    }
}

// MARK: - Result (Logic → ViewModel — fully Domain-safe)

/// One experiment's outcome, ready for the screen: `DiagnosticsOutcome` plus the
/// `DiagnosticsError` the Logic mapped it to.
public struct DiagnosticsResult: Sendable, Equatable, Identifiable {
    public let id: DiagnosticsExperiment
    public let succeeded: Bool
    public let category: String
    public let code: String
    public let requestSummary: String
    public let responseSummary: String
    public let attempts: Int
    public let wasCancelled: Bool
    public let domainError: DiagnosticsError?
    public let isRetryable: Bool

    public init(experiment: DiagnosticsExperiment, outcome: DiagnosticsOutcome) {
        self.id = experiment
        self.succeeded = outcome.succeeded
        self.category = outcome.category
        self.code = outcome.code
        self.requestSummary = outcome.requestSummary
        self.responseSummary = outcome.responseSummary
        self.attempts = outcome.attempts
        self.wasCancelled = outcome.wasCancelled
        self.domainError = outcome.succeeded ? nil : DiagnosticsError.from(category: outcome.category)
        self.isRetryable = domainError?.isRetryable ?? false
    }
}
