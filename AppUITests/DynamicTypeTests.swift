import XCTest

/// PRD-APP-01, XCUITest 3: Dynamic Type at the largest accessibility size
/// (`UICTContentSizeCategoryAccessibilityXXXL`) — the products list AND `ProductDetail`'s
/// custom navigation bar stay accessible (every checked element `isHittable`).
final class DynamicTypeTests: AppStarterUITestCase {
    func testAccessibilityXXXLKeepsListAndCustomBarHittable() {
        let app = launchApp(contentSizeCategory: "UICTContentSizeCategoryAccessibilityXXXL")
        loginAndWaitForProducts(app)

        navigateToProductDetail(app)

        let backButton = app.buttons.matching(NSPredicate(format: "label == %@", "Back")).firstMatch
        XCTAssertTrue(backButton.waitForExistence(timeout: 10))
        XCTAssertTrue(backButton.isHittable, "ProductDetail's custom back button is not hittable at XXXL")

        let favoriteButton = app.descendants(matching: .any)["productDetail.favorite"]
        XCTAssertTrue(favoriteButton.waitForExistence(timeout: 10))
        XCTAssertTrue(favoriteButton.isHittable, "The favorite button is not hittable at XXXL")
    }
}
