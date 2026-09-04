import AppFoundation
import Domain
import Foundation
import Networking
import Observation

/// Orchestrates the Settings screen: load the current toggles/environment/analytics
/// snapshot, and save a toggle change. Never imports CoreNetworking, never references
/// `SettingsStore`/`APIService` directly — only `logic`.
///
/// **Pinning takes effect on the NEXT launch, not live** (PRD-APP-02 tramo B item 2):
/// `NetworkingModule.register(in:)` reads the persisted `AppSettings` ONCE, at
/// container-registration time, to decide whether the authenticated `APIService` pins
/// TLS — every `*Service` in the app resolves and CACHES its own `any
/// APIServiceProtocol` reference from that one registration. Re-registering
/// `APIServiceProtocol` after the fact would not reach any of them. The banner this
/// ViewModel shows after a successful save says so explicitly; manual verification
/// (`README.md`) restarts the app between toggling pinning and checking its effect.
///
/// `@Observable` here too — not just the one `AppFoundation.BaseViewModel` already
/// carries (`docs/INFORME-MULTI.md` §11): the macro only instruments stored properties
/// declared IN the class it's attached to, so `settings`/`activeBaseURL`/
/// `activePinningSummary`/`recentEvents` need their own. PRD-APP-02 tramo B item 0:
/// every ViewModel declares it, on principle.
@MainActor
@Observable
public final class SettingsViewModel: LogicViewModel<any SettingsLogicProtocol>, ActionHandling {
    public private(set) var settings = AppSettings()
    public private(set) var activeBaseURL = ""
    public private(set) var activePinningSummary = ""
    public private(set) var recentEvents: [AnalyticsEvent] = []

    /// The live broadcast `RootView` observes to decide which theme is installed
    /// (`Networking`, shared singleton — see its own doc comment). Updated right after a
    /// successful `.toggleTheme` save, never before: the switch flipping and the
    /// persisted value agreeing are never out of sync.
    private let themeSettings: ThemeSettings

    public enum Action: Sendable {
        case load
        case toggleTheme(Bool)
        case togglePinningStrict(Bool)
        case toggleFakePin(Bool)
    }

    public init(logic: any SettingsLogicProtocol, themeSettings: ThemeSettings) {
        self.themeSettings = themeSettings
        super.init(logic: logic)
    }

    public func handle(_ action: Action) {
        switch action {
        case .load: load()
        case .toggleTheme(let isBrand):
            save(updating: { $0.themeIsBrand = isBrand })
        case .togglePinningStrict(let strict):
            // Turning pinning off also clears "pin falso" — a fake pin only means
            // anything while pinning itself is on; leaving it set behind the scenes
            // would silently arm it again the moment pinning is turned back on.
            save(updating: { settings in
                settings.pinningStrict = strict
                if !strict { settings.useFakePin = false }
            })
        case .toggleFakePin(let useFakePin):
            save(updating: { $0.useFakePin = useFakePin })
        }
    }

    private func load() {
        performLoad { vm in
            vm.apply(try await vm.logic.load())
        }
    }

    private func save(updating mutate: @escaping (inout AppSettings) -> Void) {
        var newSettings = settings
        mutate(&newSettings)
        performActivity(errorHandling: .banner) { vm in
            let state = try await vm.logic.save(newSettings)
            vm.apply(state)
            vm.themeSettings.setBrand(state.settings.themeIsBrand)
            // A longer-than-default duration on purpose: two sentences to read, and the
            // pinning half only takes effect on the next launch, which the user must notice.
            vm.showBanner(
                BannerState(
                    message: "Ajustes guardados. El pinning se aplica al reiniciar la app.",
                    style: .info,
                    duration: .seconds(6)
                )
            )
        }
    }

    private func apply(_ state: SettingsScreenState) {
        settings = state.settings
        activeBaseURL = state.activeBaseURL
        activePinningSummary = state.activePinningSummary
        recentEvents = state.recentEvents
    }
}
