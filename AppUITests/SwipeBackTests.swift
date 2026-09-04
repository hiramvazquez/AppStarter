import XCTest

/// PRD-APP-01, XCUITest 1: swipe-back from the screen edge on `ProductDetail` — the one
/// screen in this app that uses `chrome: .custom` — returns to the products list.
/// `ScreenContainer` installs `PopGestureEnabler` automatically whenever chrome is
/// `.custom` specifically so this keeps working; this test is what proves it, since
/// swipe-back can't be covered by a unit test.
final class SwipeBackTests: AppStarterUITestCase {
    func testSwipeBackFromProductDetailReturnsToProductsList() {
        let app = launchApp()
        let list = loginAndWaitForProducts(app)

        let detailContent = navigateToProductDetail(app)

        // Edge swipe: press near the left edge and drag to the right, the standard way
        // XCUITest simulates the system's interactive-pop gesture.
        let window = app.windows.firstMatch
        let edge = window.coordinate(withNormalizedOffset: CGVector(dx: 0.01, dy: 0.5))
        let target = window.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5))
        edge.press(forDuration: 0.05, thenDragTo: target)

        XCTAssertTrue(list.waitForExistence(timeout: 10), "Swipe-back did not return to the products list")
        XCTAssertFalse(detailContent.exists, "ProductDetail should be gone after swipe-back")
    }
}
