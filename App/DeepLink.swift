import AppFoundation
import Domain
import Foundation

/// AppStarter's deep links (PRD-APP-02 tramo B item 3): `appstarter://product/<id>`
/// (pushes `.productDetail(id:)`, replacing the whole stack — "open the app exactly
/// here") and `appstarter://search?q=<query>` (opens Search pre-filled, as a sheet).
///
/// Lives in `App/` (the cáscara), not in `Domain`: `DeepLinkType` is an `AppFoundation`
/// protocol, and `Domain` only imports `Foundation` (`AGENTS.md` § Módulos de este
/// proyecto) — parsing a URL into a route is composition, the same category of code as
/// `RootView`'s `destination(for:)` switch, not business logic.
enum AppDeepLink: DeepLinkType, Equatable {
    case product(id: Int)
    case search(query: String)

    /// `appstarter://product/3` parses as `scheme: "appstarter"`, `host: "product"`,
    /// `path: "/3"` — a custom-scheme URL's first path component is NOT in
    /// `pathComponents` the way a `https://.../product/3` URL's would be (there, "product"
    /// itself is a path component); `host` is the reliable place to read it here.
    static func parse(_ url: URL) -> AppDeepLink? {
        guard url.scheme == "appstarter" else { return nil }
        switch url.host {
        case "product":
            let idComponent = url.pathComponents.first { $0 != "/" }
            guard let idComponent, let id = Int(idComponent) else { return nil }
            return .product(id: id)
        case "search":
            guard
                let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
                let query = components.queryItems?.first(where: { $0.name == "q" })?.value,
                !query.isEmpty
            else {
                return nil
            }
            return .search(query: query)
        default:
            return nil
        }
    }
}

extension Coordinator<AppRoute> {
    /// Maps a parsed `AppDeepLink` to the `DeepLinkAction` that opens it — the one place
    /// that knows AppStarter's own route graph (`Coordinator.handle(_:as:map:)`, generic
    /// over any `DeepLinkType`, doesn't).
    @discardableResult
    func handleAppDeepLink(_ url: URL) -> Bool {
        handle(url, as: AppDeepLink.self) { link in
            switch link {
            case .product(let id):
                .setStack([.products, .productDetail(id: id)])
            case .search(let query):
                .present(.search(query: query), style: .sheet)
            }
        }
    }
}
