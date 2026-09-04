import AppFoundation
import Foundation

/// Every operation `DiagnosticsViewModel` can ask its `Logic` for: one per experiment,
/// plus reading the captured interceptor log.
public protocol DiagnosticsLogicProtocol: Logic {
    func run(_ experiment: DiagnosticsExperiment) async -> DiagnosticsResult
    func capturedLogLines() async -> [String]
}

/// ALL of the Diagnostics feature's business logic: dispatches to
/// `DiagnosticsServicing` (`Services/DiagnosticsService.swift` — this feature's own
/// minimal Service, `--no-service` completed by hand) and wraps its `DiagnosticsOutcome`
/// into a `DiagnosticsResult`, mapping the category to `DiagnosticsError` (M1) — the ONE
/// place that happens (see `DiagnosticsError.from(category:)`).
///
/// `nonisolated` (M5): not tied to the main actor.
public nonisolated final class DiagnosticsLogic: DiagnosticsLogicProtocol {
    private let diagnosticsService: any DiagnosticsServicing

    public init(diagnosticsService: any DiagnosticsServicing) {
        self.diagnosticsService = diagnosticsService
    }

    public func run(_ experiment: DiagnosticsExperiment) async -> DiagnosticsResult {
        let outcome: DiagnosticsOutcome
        switch experiment {
        case .notFound404: outcome = await diagnosticsService.run404()
        case .unauthorized401: outcome = await diagnosticsService.run401()
        case .timeout: outcome = await diagnosticsService.runTimeout()
        case .invalidJSON: outcome = await diagnosticsService.runInvalidJSON()
        case .unreachableHost: outcome = await diagnosticsService.runUnreachable()
        case .retry5xx: outcome = await diagnosticsService.runRetry5xx()
        case .slowCancelable: outcome = await diagnosticsService.runSlow()
        }
        return DiagnosticsResult(experiment: experiment, outcome: outcome)
    }

    public func capturedLogLines() async -> [String] {
        await diagnosticsService.capturedLogLines()
    }
}
