import AppFoundation
import Domain
import FavoritesFeature
import LoginFeature
import ProductDetailFeature
import ProductsFeature
import ProfileFeature
import SearchFeature
import SwiftUI

// archinit:imports

/// The app's navigation shell: `CoordinatorView` over the `Coordinator<AppRoute>`
/// `AppModule.swift` registers. Resolves every `ViewModel` from `Container.shared` —
/// never constructs one directly (the composition root already did that work).
///
/// `generate-feature` (modo multi) never edits this file: it adds the `case` to
/// `AppRoute` automatically (marker `// archinit:routes` — best-effort here, since
/// `AppRoute` lives in `Domain`, not `App/AppRoute.swift`; see `Domain/AppRoute.swift`'s
/// doc comment and `docs/INFORME-MULTI.md`) but always prints the matching `switch` arm
/// to add here by hand — the same manual step single-module `archinit` already documents.
struct RootView: View {
    @State private var coordinator = Container.shared.resolve(Coordinator<AppRoute>.self)

    var body: some View {
        CoordinatorView(coordinator: coordinator) { route in
            switch route {
            // archinit:destinations
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
