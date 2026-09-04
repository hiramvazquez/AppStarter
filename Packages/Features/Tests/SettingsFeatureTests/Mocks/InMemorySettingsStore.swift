import Foundation
import Networking

@testable import SettingsFeature

/// `SettingsStoring` backed by a plain in-memory var — what `SettingsLogicTests` runs
/// against instead of a real `UserDefaultsSettingsStore`: fast, and no state shared
/// between tests (`UserDefaultsSettingsStore` itself is tested for real, against an
/// isolated `UserDefaults(suiteName:)`, in `Stores/SettingsStoreTests.swift`).
actor InMemorySettingsStore: SettingsStoring {
    private var stored = AppSettings()

    func currentSettings() async -> AppSettings {
        stored
    }

    func save(_ settings: AppSettings) async {
        stored = settings
    }
}
