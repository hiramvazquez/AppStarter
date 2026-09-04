import Foundation
import Testing

@testable import DiagnosticsFeature

/// `DiagnosticsViewModel` tested only against `DiagnosticsLogicMock` — no
/// `DiagnosticsService`/network involved.
@Suite("DiagnosticsViewModel")
@MainActor
struct DiagnosticsViewModelTests {
    @Test("handle(.appear) reaches .content without calling the Logic")
    func appearReachesContentWithoutCallingLogic() async {
        let mock = DiagnosticsLogicMock()
        let viewModel = DiagnosticsViewModel(logic: mock)

        viewModel.handle(.appear)

        #expect(viewModel.phase == .content)
        #expect(await mock.runCalls.isEmpty)
    }

    @Test("handle(.run) stores the Logic's result for that experiment")
    func runStoresResultForExperiment() async {
        let mock = DiagnosticsLogicMock()
        let result = DiagnosticsResult(
            experiment: .notFound404,
            outcome: DiagnosticsOutcome(
                succeeded: false,
                category: "notFound",
                code: "httpStatus",
                requestSummary: "GET /products/999999",
                responseSummary: "404 — 0 bytes"
            )
        )
        mock.resultsToReturn[.notFound404] = result

        let viewModel = DiagnosticsViewModel(logic: mock)
        viewModel.handle(.run(.notFound404))
        await waitUntil { viewModel.result(for: .notFound404) != nil }

        #expect(await mock.runCalls.calls == [.notFound404])
        #expect(viewModel.result(for: .notFound404) == result)
        #expect(viewModel.isRunning(.notFound404) == false)
    }

    @Test("Two different experiments run independently — one does not cancel the other")
    func differentExperimentsRunIndependently() async {
        let mock = DiagnosticsLogicMock()
        let viewModel = DiagnosticsViewModel(logic: mock)

        viewModel.handle(.run(.notFound404))
        viewModel.handle(.run(.unauthorized401))
        await waitUntil { viewModel.result(for: .notFound404) != nil && viewModel.result(for: .unauthorized401) != nil }

        #expect(Set(await mock.runCalls.calls) == [.notFound404, .unauthorized401])
    }

    @Test("Re-running the same experiment while it's in flight is a no-op")
    func rerunningInFlightExperimentIsNoOp() async {
        let mock = DiagnosticsLogicMock()
        mock.delayBeforeReturning = .milliseconds(50)
        let viewModel = DiagnosticsViewModel(logic: mock)

        viewModel.handle(.run(.notFound404))
        #expect(viewModel.isRunning(.notFound404))
        viewModel.handle(.run(.notFound404))
        await waitUntil { viewModel.isRunning(.notFound404) == false }

        #expect(await mock.runCalls.calls == [.notFound404])
    }

    @Test("handle(.run(.slowCancelable)) goes through performLoad's inFlightLoad")
    func slowCancelableUsesInFlightLoad() async {
        let mock = DiagnosticsLogicMock()
        let viewModel = DiagnosticsViewModel(logic: mock)

        viewModel.handle(.run(.slowCancelable))

        #expect(viewModel.inFlightLoad != nil)
        await viewModel.inFlightLoad?.value

        #expect(await mock.runCalls.calls == [.slowCancelable])
        #expect(viewModel.result(for: .slowCancelable) != nil)
    }

    @Test("handle(.cancelSlow) cancels inFlightLoad — CancellationRecognizing keeps phase off .error")
    func cancelSlowCancelsInFlightLoad() async {
        let mock = DiagnosticsLogicMock()
        mock.delayBeforeReturning = .milliseconds(200)
        let viewModel = DiagnosticsViewModel(logic: mock)

        viewModel.handle(.run(.slowCancelable))
        let task = viewModel.inFlightLoad
        viewModel.handle(.cancelSlow)
        await task?.value

        #expect(task?.isCancelled == true)
        #expect(viewModel.hasError == false)
    }

    /// Polls `condition` instead of awaiting a specific `Task` — `.run(_:)` for
    /// non-`slowCancelable` experiments owns its `Task` privately (`experimentTasks`),
    /// so a test can't reach it directly the way it awaits `inFlightLoad`.
    private func waitUntil(timeout: Duration = .seconds(2), _ condition: @MainActor () -> Bool) async {
        let deadline = ContinuousClock.now + timeout
        while !condition(), ContinuousClock.now < deadline {
            try? await Task.sleep(for: .milliseconds(5))
        }
    }
}
