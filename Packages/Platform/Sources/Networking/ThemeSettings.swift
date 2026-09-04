import AppFoundation
import Foundation
import Observation

/// The live, in-memory broadcast of the "brand theme" toggle (PRD-APP-02 tramo B item
/// 2) — `RootView` observes it to decide whether the four `Brand…Style` types are
/// installed (`App/Theme/`) on `CoordinatorView`, or the kit's own defaults are left
/// alone. `@MainActor`/`@Observable`, same shape as `AppSessionState` (this file's
/// neighbor) and for the same reason: it's app-wide UI state both `App/` and a
/// `*Feature` (`SettingsFeature`, allowed to import `Networking`, `AGENTS.md`) need to
/// share as the SAME live instance, not a value type re-read on every render.
///
/// `SettingsViewModel` is the only writer (`setBrand(_:)`, called right after a
/// successful `SettingsStoring.save(_:)` — so the toggle switching visibly and the
/// persisted value agreeing with each other are never out of sync). Persistence itself
/// is `SettingsFeature`'s own concern (`Stores/SettingsStore.swift`); this class only
/// ever reads the INITIAL value once, at construction — see `AppSettings
/// .loadSynchronously(from:)`'s own doc comment for why that read is safe unlike a
/// general-purpose synchronous UserDefaults read would be.
@MainActor
@Observable
public final class ThemeSettings {
    public private(set) var isBrand: Bool

    public init(isBrand: Bool) {
        self.isBrand = isBrand
    }

    public func setBrand(_ isBrand: Bool) {
        self.isBrand = isBrand
    }
}
