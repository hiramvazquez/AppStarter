@preconcurrency import Foundation
import Networking
import Testing

@testable import SettingsFeature

/// `UserDefaultsSettingsStore` tested against a REAL `UserDefaults`, isolated with
/// `UserDefaults(suiteName:)` (PRD-APP-02 tramo B item 6) — a fresh, uniquely-named
/// suite per test, cleaned up in `deinit`-equivalent fashion (removed at the end of each
/// test) so no state leaks between runs or into the app's own `UserDefaults.standard`.
@Suite("UserDefaultsSettingsStore")
struct SettingsStoreTests {
    private func makeStore() throws -> (store: UserDefaultsSettingsStore, suiteName: String) {
        let suiteName = "com.appstarter.settings.tests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        return (UserDefaultsSettingsStore(defaults: defaults), suiteName)
    }

    @Test("currentSettings() on a fresh suite returns every toggle off")
    func currentSettingsOnFreshSuiteReturnsDefaults() async throws {
        let (store, suiteName) = try makeStore()
        defer { UserDefaults().removePersistentDomain(forName: suiteName) }

        let settings = await store.currentSettings()

        #expect(settings == AppSettings())
    }

    @Test("save(_:) then currentSettings() round-trips")
    func saveThenCurrentSettingsRoundTrips() async throws {
        let (store, suiteName) = try makeStore()
        defer { UserDefaults().removePersistentDomain(forName: suiteName) }
        let saved = AppSettings(themeIsBrand: true, pinningStrict: true, useFakePin: true)

        await store.save(saved)
        let fetched = await store.currentSettings()

        #expect(fetched == saved)
    }

    @Test("save(_:) overwrites a previously-saved value, not merges it")
    func saveOverwritesPreviousValue() async throws {
        let (store, suiteName) = try makeStore()
        defer { UserDefaults().removePersistentDomain(forName: suiteName) }

        await store.save(AppSettings(themeIsBrand: true, pinningStrict: true, useFakePin: true))
        await store.save(AppSettings(themeIsBrand: false))
        let fetched = await store.currentSettings()

        #expect(fetched == AppSettings(themeIsBrand: false, pinningStrict: false, useFakePin: false))
    }

    @Test("AppSettings.loadSynchronously(from:) reads the same key the Store writes")
    func loadSynchronouslyReadsWhatStoreWrote() async throws {
        let (store, suiteName) = try makeStore()
        defer { UserDefaults().removePersistentDomain(forName: suiteName) }
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        let saved = AppSettings(pinningStrict: true, useFakePin: true)

        await store.save(saved)

        // Same UserDefaults suite, read the OTHER way in — `NetworkingModule
        // .register(in:)`'s own bootstrap path (PRD-APP-02: `AppSettings
        // .loadSynchronously`), never the Store's own `currentSettings()`.
        #expect(AppSettings.loadSynchronously(from: defaults) == saved)
    }
}
