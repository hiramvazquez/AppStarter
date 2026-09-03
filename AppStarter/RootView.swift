import AppFoundation
import AppStarterKit
import SwiftUI

/// The app's navigation shell: `CoordinatorView` over the `Coordinator<AppRoute>`
/// `CoreModule` registered. Resolves every `ViewModel` from `Container.shared` — never
/// constructs one directly (the composition root already did that work).
struct RootView: View {
    @State private var coordinator = Container.shared.resolve(Coordinator<AppRoute>.self)

    var body: some View {
        CoordinatorView(coordinator: coordinator) { route in
            switch route {
            case .login:
                LoginView(viewModel: Container.shared.resolve())
            case .products:
                ProductsView(viewModel: Container.shared.resolve())
            case .productDetail(let id):
                let factory = Container.shared.resolve(ProductDetailViewModelFactory.self)
                ProductDetailView(viewModel: factory(id))
            case .favorites:
                FavoritesView(viewModel: Container.shared.resolve())
            case .profile:
                ProfileView(viewModel: Container.shared.resolve())
            case .search:
                SearchView(viewModel: Container.shared.resolve())
            }
        }
    }
}
