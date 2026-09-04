import XCTest

/// PRD-APP-01, XCUITest 2: VoiceOver — the custom navigation bar's back button (the
/// custom bar only appears on `ProductDetail`) exposes `accessibilityLabel` "Back",
/// checked via `XCUIElement.label` exactly as the PRD specifies, not just presence.
final class AccessibilityLabelTests: AppStarterUITestCase {
    func testProductDetailBackButtonExposesBackAccessibilityLabel() {
        let app = launchApp()
        loginAndWaitForProducts(app)

        navigateToProductDetail(app)

        let backButton = app.buttons.matching(NSPredicate(format: "label == %@", "Back")).firstMatch
        XCTAssertTrue(backButton.waitForExistence(timeout: 10), "No button with accessibilityLabel 'Back' found")
        XCTAssertEqual(backButton.label, "Back")
        XCTAssertTrue(backButton.isHittable)
    }
}
