import XCTest

/// PRD-APP-02, Fase 3: Gallery offline — opened from `ProductDetail`, its overlay bar
/// (`chrome: .custom(_, placement: .overlay)`) is present over the paging image, and
/// swipe-back (`PopGestureEnabler`, installed automatically for `.custom` chrome) returns
/// to `ProductDetail` — the offline fixture's product has three images
/// (`App/OfflineFixtures.swift`), so there is something to page/swipe between.
final class GalleryUITests: AppStarterUITestCase {
    func testOpenGalleryFromDetailShowsOverlayBarAndSwipeBackReturns() {
        let app = launchApp()
        loginAndWaitForProducts(app)

        let detailTitle = navigateToProductDetail(app)

        waitAndTap(app.buttons["productDetail.openGallery"])

        // The paging image and the overlay bar (a `NavigationBarItem.close` — labeled
        // "Close", `CustomNavigationBar`'s only role that gets an explicit
        // `accessibilityLabel`, AppFoundation's `NavigationBarItem.swift`) both need to be
        // on screen at once for `.overlay` placement to be doing its job — `.stack`
        // placement would push the image down below the bar instead.
        let firstImage = app.descendants(matching: .any)["gallery.image.0"]
        XCTAssertTrue(waitForExistenceTolerant(firstImage, in: app), "Gallery's first image did not appear")

        let closeButton = app.buttons.matching(NSPredicate(format: "label == %@", "Close")).firstMatch
        XCTAssertTrue(
            waitForExistenceTolerant(closeButton, in: app),
            "Gallery's overlay bar close button did not appear"
        )
        XCTAssertTrue(closeButton.isHittable, "The overlay bar's close button should be hittable over the image")

        // A second image proves the fixture's three-image product actually paged — not
        // just that a single image rendered under `.overlay` chrome.
        let thumbnail1 = app.descendants(matching: .any)["gallery.thumbnail.1"]
        XCTAssertTrue(waitForExistenceTolerant(thumbnail1, in: app), "Second thumbnail did not appear")
        waitAndTap(thumbnail1)
        let secondImage = app.descendants(matching: .any)["gallery.image.1"]
        XCTAssertTrue(waitForExistenceTolerant(secondImage, in: app), "Selecting the second thumbnail did not page")

        // Edge swipe (same technique as `SwipeBackTests`, ProductDetail's own swipe-back):
        // Gallery is the second screen in this app with `.custom` chrome, so this is what
        // proves `PopGestureEnabler` also engages under `.overlay` placement, not just
        // `.stack`.
        let window = app.windows.firstMatch
        let edge = window.coordinate(withNormalizedOffset: CGVector(dx: 0.01, dy: 0.5))
        let target = window.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5))
        edge.press(forDuration: 0.05, thenDragTo: target)

        XCTAssertTrue(detailTitle.waitForExistence(timeout: 10), "Swipe-back did not return to ProductDetail")
        XCTAssertFalse(firstImage.exists, "Gallery should be gone after swipe-back")
    }
}
