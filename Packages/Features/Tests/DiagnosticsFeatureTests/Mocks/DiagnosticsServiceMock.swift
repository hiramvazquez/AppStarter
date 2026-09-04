import AppFoundationTestSupport
import Foundation

@testable import DiagnosticsFeature

/// Stub that substitutes `DiagnosticsServicing` in `DiagnosticsLogicTests` — exercises
/// `DiagnosticsLogic.run(_:)`'s dispatch (one method per experiment) and its
/// `DiagnosticsError.from(category:)` mapping, without a real `APIService`/network call.
///
/// The `DiagnosticsServicing` conformance is declared in a SEPARATE `extension` below, not
/// inline on this declaration — same gotcha as `Domain/Session.swift`'s
/// `UserDefaultsSessionStore`: with `InferIsolatedConformances` + `defaultIsolation(MainActor)`
/// both active, an inline conformance to a `Sendable` protocol with `async` requirements
/// makes this class's own stored-property defaults fail to compile ("main actor-isolated
/// default value in a nonisolated context").
final class DiagnosticsServiceMock: @unchecked Sendable {
    let calls = SpyRecorder<DiagnosticsExperiment>()
    var outcomeToReturn = DiagnosticsOutcome(
        succeeded: true,
        category: "success",
        code: "-",
        requestSummary: "-",
        responseSummary: "-"
    )
    var logLinesToReturn: [String] = []
}

extension DiagnosticsServiceMock: DiagnosticsServicing {
    func run404() async -> DiagnosticsOutcome {
        await calls.record(.notFound404)
        return outcomeToReturn
    }

    func run401() async -> DiagnosticsOutcome {
        await calls.record(.unauthorized401)
        return outcomeToReturn
    }

    func runTimeout() async -> DiagnosticsOutcome {
        await calls.record(.timeout)
        return outcomeToReturn
    }

    func runInvalidJSON() async -> DiagnosticsOutcome {
        await calls.record(.invalidJSON)
        return outcomeToReturn
    }

    func runUnreachable() async -> DiagnosticsOutcome {
        await calls.record(.unreachableHost)
        return outcomeToReturn
    }

    func runRetry5xx() async -> DiagnosticsOutcome {
        await calls.record(.retry5xx)
        return outcomeToReturn
    }

    func runSlow() async -> DiagnosticsOutcome {
        await calls.record(.slowCancelable)
        return outcomeToReturn
    }

    func capturedLogLines() async -> [String] {
        logLinesToReturn
    }
}
