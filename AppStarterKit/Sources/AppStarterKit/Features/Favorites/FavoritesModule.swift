import AppFoundation
import Foundation
import SwiftData

/// Registers the Favorites feature. Owns the `ModelContainer` for `FavoriteProductRecord`
/// — the ONE place it is constructed — and registers `FavoritesStoring` from it, which
/// `ProductDetailModule` resolves too (shared store, two features).
public struct FavoritesModule: DependencyModule {
    private let modelContainer: ModelContainer

    /// - Parameter modelContainer: Defaults to a persisted, on-disk container. Tests pass
    ///   an in-memory one instead (`isStoredInMemoryOnly: true`).
    public init(modelContainer: ModelContainer? = nil) throws {
        self.modelContainer = try modelContainer ?? ModelContainer(for: FavoriteProductRecord.self)
    }

    /// An in-memory variant — never persisted between launches. `FavoriteProductRecord`
    /// is internal to this module (only `SwiftDataFavoritesStore` touches SwiftData, per
    /// the architecture's Store boundary), so a caller outside `AppStarterKit` (the app
    /// target's `-UITestOffline` wiring) can't build this `ModelContainer` itself — this
    /// is the seam that lets it ask for one anyway.
    public static func inMemory() throws -> FavoritesModule {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: FavoriteProductRecord.self, configurations: configuration)
        return try FavoritesModule(modelContainer: container)
    }

    public func register(in container: Container) {
        container.register(FavoritesStoring.self) { [modelContainer] _ in
            SwiftDataFavoritesStore(modelContainer: modelContainer)
        }

        container.register(FavoritesLogicProtocol.self) { c in
            FavoritesLogic(favoritesStore: c.resolve())
        }

        container.register(FavoritesViewModel.self, lifecycle: .transient) { c in
            FavoritesViewModel(logic: c.resolve(), router: c.resolve())
        }
    }
}
