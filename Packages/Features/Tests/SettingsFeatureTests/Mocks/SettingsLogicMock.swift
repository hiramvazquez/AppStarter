import AppFoundationTestSupport
import Foundation
import Networking

@testable import SettingsFeature

/// Spy that substitutes `SettingsLogicProtocol` in `SettingsViewModelTests` — the
/// ViewModel under test never touches a real `SettingsLogic`.
final class SettingsLogicMock: SettingsLogicProtocol {
    let loadCalls = SpyRecorder<Void>()
    let saveCalls = SpyRecorder<AppSettings>()
    var stateToReturn = SettingsScreenState(
        settings: AppSettings(),
        activeBaseURL: "https://dummyjson.com",
        activePinningSummary: "Desactivado — validación TLS del sistema",
        recentEvents: []
    )
    var errorToThrow: (any Error)?

    func load() async throws -> SettingsScreenState {
        await loadCalls.record()
        if let errorToThrow { throw errorToThrow }
        return stateToReturn
    }

    @discardableResult
    func save(_ settings: AppSettings) async throws -> SettingsScreenState {
        await saveCalls.record(settings)
        if let errorToThrow { throw errorToThrow }
        stateToReturn = SettingsScreenState(
            settings: settings,
            activeBaseURL: stateToReturn.activeBaseURL,
            activePinningSummary: stateToReturn.activePinningSummary,
            recentEvents: stateToReturn.recentEvents
        )
        return stateToReturn
    }
}
