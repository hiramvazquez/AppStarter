import AppFoundation
import DiagnosticsFeature
import Domain
import FavoritesFeature
import GalleryFeatureUI
import LoginFeature
import Networking
import ProductDetailFeature
import ProductsFeature
import ProfileFeature
import SearchFeature
import SwiftUI
import UploadsFeature

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
            destination(for: route)
                // `screen_view` on every navigation (PRD-APP-02, `AnalyticsTracking`):
                // the coordinator is the one place that sees every route, so this is the
                // one place that tracks it — no feature calls `AnalyticsTracking` for its
                // own navigation.
                .onAppear { trackScreenView(route) }
        }
    }

    @ViewBuilder
    private func destination(for route: AppRoute) -> some View {
        switch route {
        // archinit:destinations
        case .login:
            LoginView(viewModel: Container.shared.resolve())
        case .products:
            ProductsView(viewModel: Container.shared.resolve())
        case .productDetail(let id):
            let factory = Container.shared.resolve(ProductDetailViewModelFactory.self)
            ProductDetailView(viewModel: factory(id))
        case .gallery(let productID):
            let factory = Container.shared.resolve(GalleryViewModelFactory.self)
            GalleryView(viewModel: factory(productID))
        case .favorites:
            FavoritesView(viewModel: Container.shared.resolve())
        case .profile:
            // Session-scoped (PRD-APP-02, `Container(parent:)`): `ProfileModule` is
            // registered into `AppSessionState.sessionContainer`, not
            // `Container.shared` — see `AppModule.makeSessionModules()`.
            let sessionState = Container.shared.resolve(AppSessionState.self)
            ProfileView(viewModel: sessionState.sessionContainer.resolve())
        case .search(let query):
            let factory = Container.shared.resolve(SearchViewModelFactory.self)
            SearchView(viewModel: factory(query))
        case .diagnostics:
            DiagnosticsView(viewModel: Container.shared.resolve())
        case .uploads:
            UploadsView(viewModel: Container.shared.resolve())
        }
    }

    private func trackScreenView(_ route: AppRoute) {
        let analytics = Container.shared.resolve(AnalyticsTracking.self)
        let event = AnalyticsEvent(name: "screen_view", parameters: ["screen": String(describing: route)])
        Task {
            await analytics.track(event)
        }
    }
}
