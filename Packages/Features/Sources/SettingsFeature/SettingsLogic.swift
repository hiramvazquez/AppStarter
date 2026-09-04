import AppFoundation
import Domain
import Foundation
import Networking

// MARK: - The screen's own state

/// What `SettingsViewModel` renders — everything from `load()` in one shot, ready for
/// the screen: the persisted toggles, the active networking configuration (read-only —
/// PRD-APP-02: "muestra la configuración activa de `NetworkingConfiguration`"), and the
/// last N tracked analytics events (most recent last). Never a DTO (M2).
public nonisolated struct SettingsScreenState: Sendable, Equatable {
    public let settings: AppSettings
    public let activeBaseURL: String
    public let activePinningSummary: String
    public let recentEvents: [AnalyticsEvent]

    public init(
        settings: AppSettings,
        activeBaseURL: String,
        activePinningSummary: String,
        recentEvents: [AnalyticsEvent]
    ) {
        self.settings = settings
        self.activeBaseURL = activeBaseURL
        self.activePinningSummary = activePinningSummary
        self.recentEvents = recentEvents
    }
}

// MARK: - Domain errors (M1)

/// Every way this screen can fail — never `APIError`/a `UserDefaults`/persistence
/// failure directly (those stop at the Store; `UserDefaultsSettingsStore` itself never
/// throws, so `.saveFailure` exists for completeness/testability, not a real failure
/// path this Store can hit today).
public enum SettingsError: DomainError, Equatable {
    case saveFailure

    public var isRetryable: Bool { true }

    public var screenError: ScreenError {
        switch self {
        case .saveFailure:
            return ScreenError(title: "No se pudo guardar", message: "Inténtalo de nuevo.")
        }
    }
}

// MARK: - Logic

/// Every operation `SettingsViewModel` can ask its `Logic` for.
public protocol SettingsLogicProtocol: Logic {
    func load() async throws -> SettingsScreenState

    /// Persists `settings` and returns the refreshed screen state (so the caller never
    /// has to re-derive `activeBaseURL`/`activePinningSummary`/`recentEvents` itself).
    @discardableResult
    func save(_ settings: AppSettings) async throws -> SettingsScreenState
}

/// ALL of the Settings feature's business logic: combines the persisted toggles
/// (`SettingsStoring`), the app's own networking configuration (read-only — this Logic
/// never reconfigures `APIServiceProtocol` itself; see `SettingsViewModel`'s doc comment
/// on why pinning changes take effect on next launch, not live), and the last N tracked
/// events (`AnalyticsTracking`, `Domain`).
///
/// `nonisolated` (M5): not tied to the main actor.
public nonisolated final class SettingsLogic: SettingsLogicProtocol {
    private let settingsStore: any SettingsStoring
    private let analytics: any AnalyticsTracking
    private let baseURL: URL

    public init(settingsStore: any SettingsStoring, analytics: any AnalyticsTracking, baseURL: URL) {
        self.settingsStore = settingsStore
        self.analytics = analytics
        self.baseURL = baseURL
    }

    public func load() async throws -> SettingsScreenState {
        await screenState(settings: settingsStore.currentSettings())
    }

    @discardableResult
    public func save(_ settings: AppSettings) async throws -> SettingsScreenState {
        await settingsStore.save(settings)
        return await screenState(settings: settings)
    }

    private func screenState(settings: AppSettings) async -> SettingsScreenState {
        SettingsScreenState(
            settings: settings,
            activeBaseURL: baseURL.absoluteString,
            activePinningSummary: Self.pinningSummary(settings),
            recentEvents: await analytics.recentEvents()
        )
    }

    private static func pinningSummary(_ settings: AppSettings) -> String {
        guard settings.pinningStrict else { return "Desactivado — validación TLS del sistema" }
        return settings.useFakePin
            ? "Activo — pin FALSO instalado a propósito (demo .untrustedServer)"
            : "Activo — 2 pines reales de dummyjson.com"
    }
}
