import Foundation

/// Every screen AppStarter can navigate to, resolved by `RootView`'s `CoordinatorView`
/// (`AppFoundation`, `Coordinator<AppRoute>`). `.search` is presented as a sheet
/// (`router.present(.search, as: .sheet)`); every other route is pushed onto the main
/// stack. See `docs/prd/PRD-APP-01.md` for the navigation diagram this mirrors.
///
/// Lives in `Domain`, not in `App/` (where `archinit --multi` scaffolds a starter
/// `AppRoute.swift` for a brand-new, feature-less project): every `*Feature` target
/// pushes/presents OTHER features' screens (`ProductsFeature` → `.productDetail`/
/// `.favorites`/`.profile`/`.search`, `SearchFeature` → `.productDetail`…) through
/// `any Router<AppRoute>`/`Coordinator<AppRoute>`, and a Feature target cannot import
/// `App` (the executable target itself, not an importable product) — only `Domain`. This
/// is the concrete case `MultiModule.md` describes as "si navega a [otra pantalla], lo
/// hace por una ruta de `AppRoute` que resuelve la app": `AppRoute` has to be reachable
/// from both `App` and every `*Feature`, and `Domain` is the only module both depend on.
/// `generate-feature`'s best-effort route registration (marker `// archinit:routes` in
/// `../../App/AppRoute.swift`) does not find this file — see `docs/INFORME-MULTI.md` for
/// the friction and the manual step it leaves in its place (add the `case` here by hand).
public enum AppRoute: Hashable {
    case login
    case products
    case productDetail(id: Int)
    case favorites
    case profile
    case search
}
