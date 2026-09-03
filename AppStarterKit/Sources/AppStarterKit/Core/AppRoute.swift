import Foundation

/// Every screen AppStarter can navigate to, resolved by `RootView`'s `CoordinatorView`
/// (`AppFoundation`, `Coordinator<AppRoute>`). `.search` is presented as a sheet
/// (`router.present(.search, as: .sheet)`); every other route is pushed onto the main
/// stack. See `docs/prd/PRD-APP-01.md` for the navigation diagram this mirrors.
public enum AppRoute: Hashable {
    case login
    case products
    case productDetail(id: Int)
    case favorites
    case profile
    case search
}
