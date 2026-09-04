import XCTest

/// PRD-APP-02, Fase 3: Settings offline — the brand theme toggle applies LIVE (no
/// restart, `RootView`'s `@State private var themeSettings`), and the pinning toggles
/// persist and update the visible summary. Never asserts colors (that's what the
/// snapshot tests, `AppSnapshotTests`, are for — `docs/INFORME-MULTI.md`/README): this
/// test asserts STRUCTURE, which differs enough between `DefaultBannerViewStyle`
/// (`App/Theme/`'s kit default: the whole banner is one `Button`, no separate dismiss
/// control) and `BrandBannerStyle` (`App/Theme/BrandBannerStyle.swift`: message `Text`
/// plus a distinct "Cerrar" `Button`) to tell them apart without a screenshot.
final class SettingsUITests: AppStarterUITestCase {
    func testBrandThemeAppliesLiveAndPinningTogglesUpdateSummary() {
        let app = launchApp()
        loginAndWaitForProducts(app)

        waitAndTap(app.buttons["products.profile"])
        waitAndTap(app.buttons["profile.settings"])

        // A SwiftUI `Toggle` row exposes an outer Switch (the whole row, identifier on it) and
        // the inner control; tapping the row's centre lands on the label, which does not flip
        // it — the inner switch does.
        let themeToggle = app.switches["settings.themeToggle"]
        XCTAssertTrue(themeToggle.waitForExistence(timeout: 15), "Settings screen did not appear")
        XCTAssertEqual(themeToggle.value as? String, "0", "Theme should start on the kit's own style")

        // Kit style banner: the whole thing is one `Button` whose accessible label carries
        // the message — no separate "Cerrar" button exists under `DefaultBannerViewStyle`.
        let kitStyleBanner = app.buttons
            .matching(
                NSPredicate(format: "label CONTAINS %@", "Ajustes guardados")
            )
            .firstMatch
        let brandCerrarButton = app.buttons["Cerrar"]

        // Brand ON: toggle, wait for the save's info banner, confirm it is the BRAND
        // style (a distinct "Cerrar" button next to the message, not one big button).
        waitAndTap(themeToggle.switches.firstMatch)
        // The banner auto-dismisses (6 s): wait for it right away, without the tolerant
        // helper's own preamble, or it can be gone before the first check.
        XCTAssertTrue(
            brandCerrarButton.waitForExistence(timeout: 6),
            "Brand theme's banner (with its own \"Cerrar\" button) never appeared after toggling on"
        )
        XCTAssertEqual(themeToggle.value as? String, "1", "Theme toggle should reflect the saved value")

        // Diagnostics still functions with the brand `LoadingViewStyle`/`ErrorViewStyle`/
        // `EmptyViewStyle` installed (PRD-APP-02: "Diagnostics muestra el estilo de
        // marca") — the per-theme visual states themselves (loading/empty/error/content)
        // are what `AppSnapshotTests` captures pixel-for-pixel; this only proves the
        // brand-themed screen is reachable and still works end to end.
        waitAndTap(app.buttons["profile.diagnostics"])
        XCTAssertTrue(
            waitForExistenceTolerant(app.descendants(matching: .any)["diagnostics.list"], in: app),
            "Diagnostics did not render under the brand theme"
        )
        waitAndTap(app.buttons["diagnostics.run.notFound404"])
        let resultCategory = app.descendants(matching: .any)["diagnostics.result.notFound404.category"]
        XCTAssertTrue(
            waitForExistenceTolerant(resultCategory, in: app),
            "Diagnostics experiment did not resolve under the brand theme"
        )
        waitAndTap(app.navigationBars.buttons.element(boundBy: 0))

        // Back in Settings: brand OFF returns to the kit's own banner style.
        XCTAssertTrue(themeToggle.waitForExistence(timeout: 15))
        waitAndTap(themeToggle.switches.firstMatch)
        XCTAssertTrue(
            kitStyleBanner.waitForExistence(timeout: 6),
            "Kit-style banner never appeared after toggling brand theme off"
        )
        XCTAssertEqual(themeToggle.value as? String, "0")

        // Pinning: strict ON reveals the fake-pin toggle and updates the summary text —
        // `PinningPins`/`SSLPinningConfiguration` themselves only take effect on the NEXT
        // launch (`SettingsViewModel`'s doc comment), so this only checks the persisted
        // state and its visible summary, not a live TLS handshake.
        let pinningToggle = app.switches["settings.pinningToggle"]
        XCTAssertTrue(pinningToggle.waitForExistence(timeout: 10))
        waitAndTap(pinningToggle.switches.firstMatch)

        let summary = app.descendants(matching: .any)["settings.pinningSummary"]
        XCTAssertTrue(waitForExistenceTolerant(summary, in: app), "Pinning summary did not appear")
        XCTAssertTrue(
            summary.label.contains("2 pines reales"),
            "Expected the real-pins summary once pinning is strict, got: \(summary.label)"
        )

        let fakePinToggle = app.switches["settings.fakePinToggle"]
        XCTAssertTrue(waitForExistenceTolerant(fakePinToggle, in: app), "Fake-pin toggle did not appear")
        waitAndTap(fakePinToggle.switches.firstMatch)
        XCTAssertTrue(waitForExistenceTolerant(summary, in: app))
        XCTAssertTrue(
            summary.label.contains("pin FALSO"),
            "Expected the fake-pin summary once the demo toggle is on, got: \(summary.label)"
        )

        // Turning pinning back off also clears the fake pin (`SettingsViewModel.handle`)
        // — the fake-pin toggle disappears, and a fresh strict-on wouldn't silently carry
        // it over.
        waitAndTap(pinningToggle.switches.firstMatch)
        XCTAssertFalse(
            waitForExistenceTolerant(fakePinToggle, in: app, timeout: 3),
            "Fake-pin toggle should be hidden once pinning is off"
        )
    }
}
