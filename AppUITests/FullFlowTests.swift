import XCTest

/// PRD-APP-01, XCUITest 4: the complete flow — login → products list → product detail →
/// mark favorite → favorites → profile → logout — end to end, replacing what the PRD
/// calls out as manual verification.
final class FullFlowTests: AppStarterUITestCase {
    func testFullFlowLoginToLogout() {
        let app = launchApp()
        loginAndWaitForProducts(app)

        // Products → ProductDetail.
        navigateToProductDetail(app)

        // Mark as favorite, and wait for the toggle (an async `performActivity`) to
        // actually finish — its label flips to "Quitar de favoritos" only once the
        // SwiftData write completes — before navigating away, or the write can lose the
        // race against the pop.
        let favoriteButton = app.descendants(matching: .any)["productDetail.favorite"]
        waitAndTap(favoriteButton)
        let toggled = NSPredicate(format: "label == %@", "Quitar de favoritos")
        _ = XCTWaiter().wait(for: [XCTNSPredicateExpectation(predicate: toggled, object: favoriteButton)], timeout: 10)

        // Back to Products (custom bar's back button).
        let backButton = app.buttons.matching(NSPredicate(format: "label == %@", "Back")).firstMatch
        waitAndTap(backButton)

        let productsList = app.descendants(matching: .any)["products.list"]
        XCTAssertTrue(productsList.waitForExistence(timeout: 10))

        // Products → Favorites.
        waitAndTap(app.buttons["products.favorites"])
        let favoritesList = app.descendants(matching: .any)["favorites.list"]
        XCTAssertTrue(favoritesList.waitForExistence(timeout: 10))
        XCTAssertTrue(
            waitForExistenceTolerant(app.descendants(matching: .any)["favorite.1"], in: app),
            "The favorited product is not listed"
        )

        // Favorites → Products (native back).
        waitAndTap(app.navigationBars.buttons.element(boundBy: 0))
        XCTAssertTrue(productsList.waitForExistence(timeout: 10))

        // Products → Profile.
        waitAndTap(app.buttons["products.profile"])
        XCTAssertTrue(waitForExistenceTolerant(app.descendants(matching: .any)["profile.content"], in: app))

        // Logout → confirmation alert (PRD-APP-02: AlertState.destructive) → back to Login.
        waitAndTap(app.buttons["profile.logout"])
        waitAndTap(app.alerts.buttons["Cerrar sesión"])
        let username = app.textFields["login.username"]
        XCTAssertTrue(username.waitForExistence(timeout: 10), "Logout did not return to the login screen")
    }
}
