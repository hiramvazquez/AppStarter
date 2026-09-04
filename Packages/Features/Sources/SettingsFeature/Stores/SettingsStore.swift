import Foundation
import Networking

// MARK: - The store

/// Local persistence for this feature — `UserDefaults`, not SwiftData (PRD-APP-02 tramo
/// B item 2: "Store sobre `UserDefaults`"): three toggles, not records to query/sort, so
/// a single JSON blob under one key is the right shape — same choice `Domain
/// .UserDefaultsSessionStore` already made for `StoredSession`. `SettingsLogic` depends
/// on this protocol through `init` — never on `UserDefaultsSettingsStore` directly.
public protocol SettingsStoring: Sendable {
    /// The persisted settings, or `AppSettings()` (every toggle off) the first time the
    /// app runs — never throws: a missing/corrupt UserDefaults entry isn't a failure
    /// worth surfacing, it's simply "nothing saved yet."
    func currentSettings() async -> AppSettings

    func save(_ settings: AppSettings) async
}

/// The `SettingsStoring` this app runs with: an `actor` (not a lock-guarded class, M5 —
/// same reasoning as `Domain.UserDefaultsSessionStore`) wrapping `UserDefaults`.
///
/// The `SettingsStoring` conformance is declared in a SEPARATE `extension` below, not
/// inline on this declaration — `UserDefaultsSessionStore`'s own doc comment explains
/// why: with `InferIsolatedConformances` + `defaultIsolation(MainActor)` both active, an
/// INLINE conformance to a `Sendable` protocol with `async` requirements makes this
/// actor's own synchronous `init` fail to compile. Moving the conformance to an
/// `extension` avoids it — reproduced upstream, `docs/INFORME-INTEGRACION.md`.
public actor UserDefaultsSettingsStore {
    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }
}

extension UserDefaultsSettingsStore: SettingsStoring {
    public func currentSettings() async -> AppSettings {
        AppSettings.loadSynchronously(from: defaults)
    }

    public func save(_ settings: AppSettings) async {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        defaults.set(data, forKey: AppSettings.userDefaultsKey)
    }
}
