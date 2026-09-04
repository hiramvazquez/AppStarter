import AppFoundation
import Foundation
import Networking

/// Registers the Profile feature.
///
/// Session-scoped (PRD-APP-02, `Container(parent:)`): `App/AppStarterApp.swift` hands this
/// to `AppSessionState.makeSessionModules`, so it is registered into a FRESH child
/// container on every login — `c.resolve(RefreshActivityLog.self)` below resolves the
/// child's own registration (`AppSessionState.startSession()`), never a copy shared with a
/// previous session.
public struct ProfileModule: DependencyModule {
    public init() {}

    public func register(in container: Container) {
        container.register(ProfileServicing.self) { c in
            ProfileService(api: c.resolve())
        }

        container.register(ProfileLogicProtocol.self) { c in
            ProfileLogic(profileService: c.resolve(), sessionStore: c.resolve())
        }

        container.register(ProfileViewModel.self, lifecycle: .transient) { c in
            ProfileViewModel(
                logic: c.resolve(),
                sessionState: c.resolve(AppSessionState.self),
                refreshLog: c.resolve(RefreshActivityLog.self)
            )
        }
    }
}
