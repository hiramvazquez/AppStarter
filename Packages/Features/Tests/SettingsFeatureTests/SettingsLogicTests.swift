import Domain
import Foundation
import Networking
import PlatformTestSupport
import Testing

@testable import SettingsFeature

@Suite("SettingsLogic")
struct SettingsLogicTests {
    private static let baseURL = URL(string: "https://dummyjson.com")!

    @Test("load() returns what the store has, the active baseURL, and recent analytics events")
    func loadReturnsStoreAndEnvironment() async throws {
        let store = InMemorySettingsStore()
        await store.save(AppSettings(themeIsBrand: true, pinningStrict: false, useFakePin: false))
        let analytics = InMemoryAnalytics()
        await analytics.track(AnalyticsEvent(name: "screen_view", parameters: ["screen": "products"]))
        let logic = SettingsLogic(settingsStore: store, analytics: analytics, baseURL: Self.baseURL)

        let state = try await logic.load()

        #expect(state.settings == AppSettings(themeIsBrand: true, pinningStrict: false, useFakePin: false))
        #expect(state.activeBaseURL == "https://dummyjson.com")
        #expect(state.recentEvents.map(\.name) == ["screen_view"])
    }

    @Test("load() on a fresh store returns every toggle off")
    func loadOnFreshStoreReturnsDefaults() async throws {
        let logic = SettingsLogic(
            settingsStore: InMemorySettingsStore(),
            analytics: InMemoryAnalytics(),
            baseURL: Self.baseURL
        )

        let state = try await logic.load()

        #expect(state.settings == AppSettings())
    }

    @Test("save(_:) persists to the store and returns the refreshed screen state")
    func savePersistsAndReturnsRefreshedState() async throws {
        let store = InMemorySettingsStore()
        let logic = SettingsLogic(settingsStore: store, analytics: InMemoryAnalytics(), baseURL: Self.baseURL)
        let saved = AppSettings(themeIsBrand: true, pinningStrict: true, useFakePin: false)

        let state = try await logic.save(saved)

        #expect(state.settings == saved)
        #expect(await store.currentSettings() == saved)
    }

    @Test("activePinningSummary reflects strict/fake-pin combinations")
    func pinningSummaryReflectsSettings() async throws {
        let logic = SettingsLogic(
            settingsStore: InMemorySettingsStore(),
            analytics: InMemoryAnalytics(),
            baseURL: Self.baseURL
        )

        let off = try await logic.save(AppSettings(pinningStrict: false))
        #expect(off.activePinningSummary.contains("Desactivado"))

        let real = try await logic.save(AppSettings(pinningStrict: true, useFakePin: false))
        #expect(real.activePinningSummary.contains("2 pines reales"))

        let fake = try await logic.save(AppSettings(pinningStrict: true, useFakePin: true))
        #expect(fake.activePinningSummary.contains("FALSO"))
    }
}
