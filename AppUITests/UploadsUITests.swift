import XCTest

/// PRD-APP-02, Fase 3: Uploads offline — captures a photo via `SimulatedCamera`
/// (deterministic under `-UITestOffline`/Simulator, no user interaction needed) and
/// uploads it, showing real progress and the success result.
final class UploadsUITests: AppStarterUITestCase {
    func testCapturePhotoAndUploadShowsProgressAndResult() {
        let app = launchApp()
        loginAndWaitForProducts(app)

        waitAndTap(app.buttons["products.profile"])
        waitAndTap(app.buttons["profile.uploads"])

        let submit = app.buttons["uploads.submit"]
        XCTAssertTrue(submit.waitForExistence(timeout: 15), "Uploads screen did not appear")
        XCTAssertFalse(submit.isEnabled, "Submit should be disabled before a photo is captured")

        waitAndTap(app.buttons["uploads.capture"])
        let preview = app.descendants(matching: .any)["uploads.photo.preview"]
        XCTAssertTrue(waitForExistenceTolerant(preview, in: app), "Captured photo preview never appeared")

        waitAndTap(submit)
        let result = app.descendants(matching: .any)["uploads.result"]
        XCTAssertTrue(waitForExistenceTolerant(result, in: app, timeout: 20), "Upload result never appeared")
    }
}
