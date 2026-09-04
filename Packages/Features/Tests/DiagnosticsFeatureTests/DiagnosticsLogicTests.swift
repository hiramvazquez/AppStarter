import Foundation
import Testing

@testable import DiagnosticsFeature

@Suite("DiagnosticsLogic")
struct DiagnosticsLogicTests {
    @Test(
        "run(_:) dispatches to the matching DiagnosticsServicing method",
        arguments: DiagnosticsExperiment.allCases
    )
    func runDispatchesToMatchingServiceMethod(experiment: DiagnosticsExperiment) async {
        let service = DiagnosticsServiceMock()
        let logic = DiagnosticsLogic(diagnosticsService: service)

        _ = await logic.run(experiment)

        #expect(await service.calls.calls == [experiment])
    }

    @Test("A successful outcome maps to a result with no DomainError")
    func successfulOutcomeHasNoDomainError() async {
        let service = DiagnosticsServiceMock()
        service.outcomeToReturn = DiagnosticsOutcome(
            succeeded: true,
            category: "success",
            code: "-",
            requestSummary: "GET /products/1",
            responseSummary: "200 — 128 bytes"
        )
        let logic = DiagnosticsLogic(diagnosticsService: service)

        let result = await logic.run(.notFound404)

        #expect(result.succeeded)
        #expect(result.domainError == nil)
        #expect(result.isRetryable == false)
    }

    @Test(
        "A failing outcome maps its category to the matching DiagnosticsError",
        arguments: [
            ("notFound", DiagnosticsError.notFound),
            ("unauthorized", DiagnosticsError.unauthorized),
            ("timeout", DiagnosticsError.timeout),
            ("decoding", DiagnosticsError.decoding),
            ("unreachable", DiagnosticsError.unreachable),
            ("server", DiagnosticsError.server),
            ("cancelled", DiagnosticsError.cancelled),
            ("somethingUnmapped", DiagnosticsError.unknown)
        ]
    )
    func failingOutcomeMapsCategoryToDomainError(category: String, expected: DiagnosticsError) async {
        let service = DiagnosticsServiceMock()
        service.outcomeToReturn = DiagnosticsOutcome(
            succeeded: false,
            category: category,
            code: "someCode",
            requestSummary: "-",
            responseSummary: "-"
        )
        let logic = DiagnosticsLogic(diagnosticsService: service)

        let result = await logic.run(.notFound404)

        #expect(result.domainError == expected)
        #expect(result.isRetryable == expected.isRetryable)
    }

    @Test("A 5xx-with-retries outcome carries its attempt count through")
    func retryOutcomeCarriesAttemptCount() async {
        let service = DiagnosticsServiceMock()
        service.outcomeToReturn = DiagnosticsOutcome(
            succeeded: true,
            category: "success",
            code: "-",
            requestSummary: "GET /diagnostics/retry-demo",
            responseSummary: "200 — 2 bytes",
            attempts: 3
        )
        let logic = DiagnosticsLogic(diagnosticsService: service)

        let result = await logic.run(.retry5xx)

        #expect(result.attempts == 3)
    }

    @Test("capturedLogLines() forwards the Service's buffer")
    func capturedLogLinesForwardsServiceBuffer() async {
        let service = DiagnosticsServiceMock()
        service.logLinesToReturn = ["→ intento 1: GET /diagnostics/retry-demo", "← intento 1: 503"]
        let logic = DiagnosticsLogic(diagnosticsService: service)

        let lines = await logic.capturedLogLines()

        #expect(lines == service.logLinesToReturn)
    }
}
