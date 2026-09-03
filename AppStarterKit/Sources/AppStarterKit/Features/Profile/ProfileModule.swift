import AppFoundation
import Foundation

/// Registers the Profile feature.
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
            ProfileViewModel(logic: c.resolve(), router: c.resolve(), refreshLog: c.resolve(RefreshActivityLog.self))
        }
    }
}
