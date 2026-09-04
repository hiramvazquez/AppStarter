import AppFoundation
import Domain
import Foundation
import Networking

/// Registers the Settings feature. `SettingsStoring` is this feature's OWN store
/// (`Stores/SettingsStore.swift`, constructed here — no other module needs it); `Theme
/// Settings`/`AnalyticsTracking` (`Networking`/`Domain`) are resolved, never
/// constructed — owned by `NetworkingModule`/`PlatformModule` respectively.
public struct SettingsModule: DependencyModule {
    /// DummyJSON's base URL — shown read-only ("la configuración activa de
    /// `NetworkingConfiguration`", PRD-APP-02). Same parameter shape as
    /// `DiagnosticsModule`.
    private let baseURL: URL

    public init(baseURL: URL) {
        self.baseURL = baseURL
    }

    public func register(in container: Container) {
        container.register(SettingsStoring.self) { _ in UserDefaultsSettingsStore() }

        container.register(SettingsLogicProtocol.self) { [baseURL] c in
            SettingsLogic(settingsStore: c.resolve(), analytics: c.resolve(), baseURL: baseURL)
        }

        container.register(SettingsViewModel.self, lifecycle: .transient) { c in
            SettingsViewModel(logic: c.resolve(), themeSettings: c.resolve())
        }
    }
}
