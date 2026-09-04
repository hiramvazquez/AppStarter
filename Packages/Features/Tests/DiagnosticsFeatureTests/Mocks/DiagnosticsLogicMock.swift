import AppFoundationTestSupport
import Foundation

@testable import DiagnosticsFeature

/// Spy that substitutes `DiagnosticsLogicProtocol` in `DiagnosticsViewModelTests` — the
/// ViewModel under test never touches a real `DiagnosticsLogic`/`DiagnosticsService`.
final class DiagnosticsLogicMock: DiagnosticsLogicProtocol, @unchecked Sendable {
    let runCalls = SpyRecorder<DiagnosticsExperiment>()
    var resultsToReturn: [DiagnosticsExperiment: DiagnosticsResult] = [:]
    /// Extra delay before `run(_:)` returns — lets a test cancel a still-in-flight call.
    var delayBeforeReturning: Duration?
    var logLinesToReturn: [String] = []

    func run(_ experiment: DiagnosticsExperiment) async -> DiagnosticsResult {
        await runCalls.record(experiment)
        if let delayBeforeReturning {
            try? await Task.sleep(for: delayBeforeReturning)
        }
        if let result = resultsToReturn[experiment] {
            return result
        }
        return DiagnosticsResult(
            experiment: experiment,
            outcome: DiagnosticsOutcome(
                succeeded: !Task.isCancelled,
                category: Task.isCancelled ? "cancelled" : "success",
                code: "-",
                requestSummary: "-",
                responseSummary: "-",
                wasCancelled: Task.isCancelled
            )
        )
    }

    func capturedLogLines() async -> [String] {
        logLinesToReturn
    }
}
