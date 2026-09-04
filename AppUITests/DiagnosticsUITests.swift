import XCTest

/// PRD-APP-02, Fase 3: Diagnostics offline — every experiment is reachable, runs against
/// `-UITestOffline`'s fixtures (`App/OfflineFixtures.swift`), and shows the category the
/// Logic mapped it to, without depending on the real API being reachable.
final class DiagnosticsUITests: AppStarterUITestCase {
    func testDiagnosticsExperimentsShowCategories() {
        let app = launchApp()
        loginAndWaitForProducts(app)

        waitAndTap(app.buttons["products.profile"])
        waitAndTap(app.buttons["profile.diagnostics"])

        let list = app.descendants(matching: .any)["diagnostics.list"]
        XCTAssertTrue(list.waitForExistence(timeout: 15), "Diagnostics list did not appear")

        // 404: the offline fixture answers `GET /products/999999` with a real 404.
        waitAndTap(app.buttons["diagnostics.run.notFound404"])
        let notFoundCategory = app.descendants(matching: .any)["diagnostics.result.notFound404.category"]
        XCTAssertTrue(waitForExistenceTolerant(notFoundCategory, in: app), "404 experiment never showed a result")
        XCTAssertTrue(
            notFoundCategory.label.contains("notFound"),
            "Expected category notFound, got: \(notFoundCategory.label)"
        )

        // 401: the dedicated offline transport answers `GET /auth/me` with a real 401.
        waitAndTap(app.buttons["diagnostics.run.unauthorized401"])
        let unauthorizedCategory = app.descendants(matching: .any)["diagnostics.result.unauthorized401.category"]
        XCTAssertTrue(waitForExistenceTolerant(unauthorizedCategory, in: app), "401 experiment never showed a result")

        // 5xx with retries: the fixture answers 503, 503, 200 — 3 attempts, and the
        // captured RequestCounterInterceptor log becomes visible.
        waitAndTap(app.buttons["diagnostics.run.retry5xx"])
        let attempts = app.descendants(matching: .any)["diagnostics.result.retry5xx.attempts"]
        XCTAssertTrue(waitForExistenceTolerant(attempts, in: app), "retry5xx experiment never showed an attempt count")
        XCTAssertTrue(
            waitForExistenceTolerant(app.descendants(matching: .any)["diagnostics.log"], in: app),
            "Captured log section never appeared"
        )

        // Slow/cancelable: tap "Run", then "Cancelar" before it resolves (the offline
        // fixture's 4s latency leaves a comfortable window) — the result shows
        // `wasCancelled`, never a full-screen error (CancellationRecognizing).
        waitAndTap(app.buttons["diagnostics.run.slowCancelable"])
        waitAndTap(app.buttons["diagnostics.cancel.slowCancelable"])
        let cancelledLabel = app.descendants(matching: .any)["diagnostics.result.slowCancelable.cancelled"]
        XCTAssertTrue(waitForExistenceTolerant(cancelledLabel, in: app), "Cancelling never showed the cancelled state")
    }
}
