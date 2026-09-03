import XCTest

/// Shared launch helper for every XCUITest in this target.
///
/// Network mode (PRD-APP-01): by DEFAULT these tests run against the REAL DummyJSON API
/// — that is the point of the PRD. CI sets `UI_TEST_OFFLINE=1` in the test process'
/// environment (not the app's — `xcodebuild test`'s `-testEnvironmentVariablesForXCTest`/
/// scheme "Test" action) to append `-UITestOffline` to the APP's launch arguments,
/// switching it to `InMemoryTransport` with recorded responses instead
/// (`AppStarter/OfflineFixtures.swift`) — no network dependency, no flakiness from the
/// real service in CI.
class AppStarterUITestCase: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// Launches a fresh `XCUIApplication`, optionally forcing Dynamic Type via
    /// `-UIPreferredContentSizeCategoryName`.
    func launchApp(contentSizeCategory: String? = nil) -> XCUIApplication {
        let app = XCUIApplication()
        var arguments = ["-UITestOffline"]
        // Real network unless CI opted into the offline fixtures.
        if ProcessInfo.processInfo.environment["UI_TEST_OFFLINE"] != "1" {
            arguments.removeAll()
        }
        if let contentSizeCategory {
            arguments += ["-UIPreferredContentSizeCategoryName", contentSizeCategory]
        }
        app.launchArguments = arguments
        app.launch()
        return app
    }

    /// Logs in with DummyJSON's published test account and waits for the products list.
    @discardableResult
    func loginAndWaitForProducts(_ app: XCUIApplication, timeout: TimeInterval = 20) -> XCUIElement {
        let username = app.textFields["login.username"]
        XCTAssertTrue(username.waitForExistence(timeout: timeout))
        username.tap()
        username.typeText("emilys")

        let password = app.secureTextFields["login.password"]
        XCTAssertTrue(password.exists)
        password.tap()
        password.typeText("emilyspass")

        app.buttons["login.submit"].tap()
        dismissSystemAlertIfPresent(app, timeout: 3)

        let list = app.descendants(matching: .any)["products.list"]
        XCTAssertTrue(list.waitForExistence(timeout: timeout), "Products list did not appear after login")
        return list
    }

    /// Dismisses the simulator's own "Save Password?" sheet if present — an iOS system
    /// UI, not this app's. `LoginView` skips `SecureField`'s `.textContentType(.password)`
    /// while under XCUITest specifically to avoid it, but the sheet is a system heuristic
    /// keyed off more than content type (confirmed empirically: it still appeared some
    /// runs, at unpredictable points after submit — never before, PRD-APP-01,
    /// `docs/INFORME-INTEGRACION.md`), so every navigation helper checks for it too, not
    /// just the one right after login.
    func dismissSystemAlertIfPresent(_ app: XCUIApplication, timeout: TimeInterval) {
        let notNow = app.buttons["Ahora no"]
        if notNow.waitForExistence(timeout: timeout) {
            notNow.tap()
            return
        }
        let notNowEnglish = app.buttons["Not Now"]
        if notNowEnglish.waitForExistence(timeout: 0.5) {
            notNowEnglish.tap()
        }
    }

    /// Waits for `element` to exist AND be hittable, then taps it. `waitForExistence`
    /// alone isn't enough: it can return `true` mid-transition (`ScreenContainer`
    /// animates phase changes), while the element's hit-testable frame is still
    /// settling — tapping immediately can hit "not hittable" even though the element is
    /// already in the accessibility tree. Checks for (and dismisses) the system
    /// "Save Password?" sheet both before and after the hittable wait, since it can
    /// appear at any point and silently blocks every tap while it's up.
    @discardableResult
    func waitAndTap(_ element: XCUIElement, timeout: TimeInterval = 15, file: StaticString = #filePath, line: UInt = #line) -> XCUIElement {
        let app = XCUIApplication()
        XCTAssertTrue(element.waitForExistence(timeout: timeout), "Element did not appear: \(element)", file: file, line: line)
        dismissSystemAlertIfPresent(app, timeout: 0.5)

        let hittable = NSPredicate(format: "isHittable == true")
        var result = XCTWaiter().wait(for: [XCTNSPredicateExpectation(predicate: hittable, object: element)], timeout: timeout)
        if result != .completed {
            // One more chance: the sheet may have appeared mid-wait.
            dismissSystemAlertIfPresent(app, timeout: 1)
            result = XCTWaiter().wait(for: [XCTNSPredicateExpectation(predicate: hittable, object: element)], timeout: 5)
        }
        XCTAssertEqual(result, .completed, "Element never became hittable: \(element)", file: file, line: line)
        element.tap()
        return element
    }

    /// Waits for `element` to exist, dismissing the system "Save Password?" sheet first
    /// (and once more if it appeared mid-wait) — same rationale as `waitAndTap`, for call
    /// sites that only need existence, not a tap.
    @discardableResult
    func waitForExistenceTolerant(_ element: XCUIElement, in app: XCUIApplication, timeout: TimeInterval = 15) -> Bool {
        dismissSystemAlertIfPresent(app, timeout: 0.5)
        if element.waitForExistence(timeout: timeout) { return true }
        dismissSystemAlertIfPresent(app, timeout: 1)
        return element.waitForExistence(timeout: 5)
    }

    /// Taps the `product.1` row from the products list and waits for `ProductDetail` to
    /// load, RE-TAPPING (up to 2 extra attempts) if the detail title doesn't show up in
    /// time — a synthesized tap landing on a `List` row right after it first appears can
    /// silently miss on a loaded/slower simulator without either side reporting an error
    /// (no "not hittable", no navigation), which is what made a single-shot tap flaky
    /// here specifically. `docs/INFORME-INTEGRACION.md`.
    @discardableResult
    func navigateToProductDetail(_ app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) -> XCUIElement {
        let row = app.descendants(matching: .any)["product.1"]
        let title = app.descendants(matching: .any)["productDetail.title"]

        for attempt in 1...3 {
            if title.exists { break }
            waitAndTap(row, file: file, line: line)
            if waitForExistenceTolerant(title, in: app, timeout: attempt == 3 ? 15 : 6) {
                break
            }
        }
        XCTAssertTrue(title.exists, "ProductDetail did not appear after retrying the tap on product.1", file: file, line: line)
        return title
    }
}
