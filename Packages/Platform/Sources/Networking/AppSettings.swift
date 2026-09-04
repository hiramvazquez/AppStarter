import Foundation

/// The three user-facing toggles `Settings` persists (PRD-APP-02 tramo B item 2):
/// which theme is installed, whether the authenticated pipeline pins TLS, and whether
/// that pinning uses the deliberately-wrong pin (`.untrustedServer` demo). `Sendable`/
/// `Equatable`/`Codable` — the same JSON-blob-in-one-key persistence shape
/// `StoredSession` already uses.
///
/// Lives in `Networking`, not inside `SettingsFeature`: `NetworkingModule` needs to read
/// `pinningStrict`/`useFakePin` SYNCHRONOUSLY, once, at container-registration time
/// (`register(in:)` isn't `async`) to decide whether the authenticated `APIService` pins
/// TLS at all — going through `SettingsFeature`'s own `actor` Store would need an
/// `await` this call site can't offer. `SettingsFeature` (a `*Feature`, allowed to import
/// `Networking`, `AGENTS.md`) reads/writes the SAME struct through its own
/// `SettingsStoring`/`UserDefaultsSettingsStore` (`Stores/SettingsStore.swift`) — one
/// data contract, two access patterns for two different callers.
public nonisolated struct AppSettings: Sendable, Equatable, Codable {
    public var themeIsBrand: Bool
    public var pinningStrict: Bool
    public var useFakePin: Bool

    public init(themeIsBrand: Bool = false, pinningStrict: Bool = false, useFakePin: Bool = false) {
        self.themeIsBrand = themeIsBrand
        self.pinningStrict = pinningStrict
        self.useFakePin = useFakePin
    }

    /// `public`: `SettingsFeature`'s own `UserDefaultsSettingsStore` (a different module,
    /// `Stores/SettingsStore.swift`) reads/writes the SAME key — one data contract.
    public static let userDefaultsKey = "com.appstarter.settings"

    /// A synchronous, one-shot read for bootstrap code that cannot `await` —
    /// `NetworkingModule.register(in:)` (deciding whether to pin the authenticated
    /// `APIService`) and `ThemeSettings.init` (the live, `@Observable` broadcast
    /// `RootView` reads). Safe precisely BECAUSE it only ever runs once, before the app
    /// becomes concurrent (the same justification `App/OfflineFixtures.swift`'s
    /// `DispatchSemaphore` bridge already documents for its own launch-time-only
    /// synchronous read).
    public static func loadSynchronously(from defaults: UserDefaults = .standard) -> AppSettings {
        guard
            let data = defaults.data(forKey: userDefaultsKey),
            let decoded = try? JSONDecoder().decode(AppSettings.self, from: data)
        else {
            return AppSettings()
        }
        return decoded
    }
}
