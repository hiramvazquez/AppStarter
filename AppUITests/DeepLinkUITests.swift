import XCTest

/// PRD-APP-02, Fase 3: deep links, offline — `appstarter://product/<id>` and
/// `appstarter://search?q=<query>` end to end through `.onOpenURL`
/// (`App/AppStarterApp.swift`) → `Coordinator.handleAppDeepLink(_:)` (`App/DeepLink.swift`).
///
/// **Option chosen: `xcrun simctl openurl booted <url>`, not `launchArguments`/
/// `launchEnvironment`.** The PRD offers either; this app's `.onOpenURL` is wired to a
/// REAL `URL` delivered by the system (SwiftUI's own scene-URL machinery), which is
/// exactly what `simctl openurl` triggers on the booted simulator — no app-side code
/// needed to translate a launch argument into a synthetic `onOpenURL` call. The
/// alternative (reading a `-DeepLinkURL <url>` launch argument in `AppStarterApp.init()`
/// and feeding it into the SAME `Coordinator.handleAppDeepLink(_:)` manually) would only
/// exercise the parsing/routing, not the actual `onOpenURL` delivery path a real deep
/// link takes in production — the thing this XCUITest exists to prove keeps working, on
/// top of `AppTests/DeepLinkTests.swift`'s unit coverage of `AppDeepLink.parse(_:)`
/// itself. Manual verification against the real API already confirmed both links resolve
/// (`docs/screenshots/02-deeplink-product.png`, `03-deeplink-search.png`); this is the
/// offline, automated version of the same check, run from a session already logged in
/// (a deep link's `setStack`/`present` doesn't itself authenticate).
final class DeepLinkUITests: AppStarterUITestCase {
    func testProductDeepLinkReplacesStackWithProductDetail() {
        let app = launchApp()
        loginAndWaitForProducts(app)

        openURL("appstarter://product/1", in: app)

        let title = app.descendants(matching: .any)["productDetail.title"]
        XCTAssertTrue(waitForExistenceTolerant(title, in: app, timeout: 15), "Deep link did not open ProductDetail")

        // `.setStack` REPLACES the whole navigation stack (`AppDeepLink.handleAppDeepLink`)
        // — Products should no longer be underneath it.
        XCTAssertFalse(
            app.descendants(matching: .any)["products.list"].exists,
            "Products should be gone from the stack"
        )
    }

    func testSearchDeepLinkPresentsSheetPrefilledAndAutoSearches() {
        let app = launchApp()
        loginAndWaitForProducts(app)

        // The offline fixture only stubs `GET /products/search?q=mascara`
        // (`App/OfflineFixtures.swift`) — the same query the manual verification
        // screenshot (`docs/screenshots/03-deeplink-search.png`) used against the real API.
        openURL("appstarter://search?q=mascara", in: app)

        let results = app.descendants(matching: .any)["search.results"]
        XCTAssertTrue(waitForExistenceTolerant(results, in: app, timeout: 15), "Search sheet did not open")
        // `.appear`'s auto-search (SearchView's doc comment) fires because the query
        // arrived pre-filled, not empty — the fixture's one product (`App/OfflineFixtures
        // .productTitle`) showing up is the proof it ran. `SearchView`'s result row
        // (unlike `ProductsView`'s) carries no `accessibilityIdentifier` of its own, so
        // this matches by the title text instead.
        XCTAssertTrue(
            waitForExistenceTolerant(app.staticTexts["Essence Mascara Lash Princess"], in: app),
            "Deep-linked search did not auto-run and show the fixture's result"
        )

        // `search.close`'s `id` (`SearchView`'s `.close(id: "search.close", ...)`) only
        // disambiguates `NavigationBarItem`'s own `Identifiable` conformance for
        // `ForEach` — `NavigationBarItemView` never turns it into an
        // `accessibilityIdentifier` (confirmed reading AppFoundation's
        // `NavigationBar/CustomNavigationBar.swift`), so this matches the same way
        // `SwipeBackTests`/`GalleryUITests` do: by the localized "Close" accessibility
        // label every close-role item gets (`CloseButtonAccessibility`).
        waitAndTap(app.buttons.matching(NSPredicate(format: "label == %@", "Close")).firstMatch)
        XCTAssertTrue(
            waitForExistenceTolerant(app.descendants(matching: .any)["products.list"], in: app),
            "Closing the search sheet should return to Products"
        )
    }

    /// Delivers `urlString` to the app under test via the simulator itself — see the type
    /// doc comment for why this, not a launch argument, is what this suite uses.
    /// `XCUIApplication.open(_:)` (iOS 16.4+) delivers the URL to the app under test exactly
    /// like a tap on a link would — `Process`/`xcrun simctl` is not available on iOS, and a
    /// launch argument would fire before the login the test needs first.
    private func openURL(_ urlString: String, in app: XCUIApplication) {
        guard let url = URL(string: urlString) else {
            XCTFail("Invalid deep link: \(urlString)")
            return
        }
        app.open(url)
    }
}
