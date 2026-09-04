import Foundation
import Networking
import Observation
import PlatformTestSupport
import Testing

@testable import SettingsFeature

/// `SettingsViewModel` tested only against `SettingsLogicMock` — no `SettingsStore`
/// real, no `UserDefaults`, no `ThemeSettings` mutation beyond the plain assertions
/// below (a real, throwaway instance — never `Container.shared`'s).
@Suite("SettingsViewModel")
@MainActor
struct SettingsViewModelTests {
    @Test("handle(.load) calls logic.load and reaches .content")
    func loadReachesContent() async {
        let mock = SettingsLogicMock()
        mock.stateToReturn = SettingsScreenState(
            settings: AppSettings(themeIsBrand: true),
            activeBaseURL: "https://dummyjson.com",
            activePinningSummary: "Desactivado — validación TLS del sistema",
            recentEvents: []
        )
        let viewModel = SettingsViewModel(logic: mock, themeSettings: ThemeSettings(isBrand: false))

        viewModel.handle(.load)
        await viewModel.inFlightLoad?.value

        #expect(await mock.loadCalls.count == 1)
        #expect(viewModel.phase == .content)
        #expect(viewModel.settings.themeIsBrand)
        #expect(viewModel.activeBaseURL == "https://dummyjson.com")
    }

    @Test("A failing logic.load lands on .error")
    func loadFailureSurfacesError() async {
        let mock = SettingsLogicMock()
        mock.errorToThrow = SettingsError.saveFailure
        let viewModel = SettingsViewModel(logic: mock, themeSettings: ThemeSettings(isBrand: false))

        viewModel.handle(.load)
        await viewModel.inFlightLoad?.value

        #expect(viewModel.hasError)
    }

    @Test("handle(.toggleTheme) saves the new value and updates the shared ThemeSettings")
    func toggleThemeSavesAndUpdatesThemeSettings() async {
        let mock = SettingsLogicMock()
        let themeSettings = ThemeSettings(isBrand: false)
        let viewModel = SettingsViewModel(logic: mock, themeSettings: themeSettings)

        viewModel.handle(.toggleTheme(true))
        await viewModel.inFlightActivity?.value

        #expect(await mock.saveCalls.calls == [AppSettings(themeIsBrand: true)])
        #expect(viewModel.settings.themeIsBrand)
        #expect(themeSettings.isBrand)
        #expect(viewModel.banner != nil)
    }

    @Test("handle(.togglePinningStrict(false)) also clears useFakePin")
    func disablingPinningClearsFakePin() async {
        let mock = SettingsLogicMock()
        mock.stateToReturn = SettingsScreenState(
            settings: AppSettings(pinningStrict: true, useFakePin: true),
            activeBaseURL: "https://dummyjson.com",
            activePinningSummary: "",
            recentEvents: []
        )
        let viewModel = SettingsViewModel(logic: mock, themeSettings: ThemeSettings(isBrand: false))
        viewModel.handle(.load)
        await viewModel.inFlightLoad?.value

        viewModel.handle(.togglePinningStrict(false))
        await viewModel.inFlightActivity?.value

        #expect(await mock.saveCalls.calls.last == AppSettings(pinningStrict: false, useFakePin: false))
    }

    @Test("handle(.toggleFakePin) saves with useFakePin flipped, pinningStrict untouched")
    func toggleFakePinSavesWithStrictUnchanged() async {
        let mock = SettingsLogicMock()
        mock.stateToReturn = SettingsScreenState(
            settings: AppSettings(pinningStrict: true, useFakePin: false),
            activeBaseURL: "https://dummyjson.com",
            activePinningSummary: "",
            recentEvents: []
        )
        let viewModel = SettingsViewModel(logic: mock, themeSettings: ThemeSettings(isBrand: false))
        viewModel.handle(.load)
        await viewModel.inFlightLoad?.value

        viewModel.handle(.toggleFakePin(true))
        await viewModel.inFlightActivity?.value

        #expect(await mock.saveCalls.calls.last == AppSettings(pinningStrict: true, useFakePin: true))
    }

    @Test("Changing settings notifies Observation — SettingsViewModel declares its own @Observable (§11)")
    func changingSettingsNotifiesObservation() async {
        let mock = SettingsLogicMock()
        // Must actually CHANGE the value from the ViewModel's initial `AppSettings()`
        // default — otherwise `settings = state.settings` (inside `apply(_:)`) assigns an
        // EQUAL value, and this test couldn't tell "notifies on change" apart from
        // "never notifies at all."
        mock.stateToReturn = SettingsScreenState(
            settings: AppSettings(themeIsBrand: true),
            activeBaseURL: "https://dummyjson.com",
            activePinningSummary: "",
            recentEvents: []
        )
        let viewModel = SettingsViewModel(logic: mock, themeSettings: ThemeSettings(isBrand: false))
        let flag = ObservationFlag()

        withObservationTracking {
            _ = viewModel.settings
        } onChange: {
            flag.fired = true
        }
        viewModel.handle(.load)
        await viewModel.inFlightLoad?.value

        #expect(flag.fired)
    }
}
