import AppFoundation
import Domain
import Foundation
import Testing

@testable import AppStarter

/// `AppDeepLink.parse(_:)` and `Coordinator.handleAppDeepLink(_:)` — PRD-APP-02 tramo B
/// item 3. Tests the parser (no `Coordinator` involved) and the routing it produces
/// (a real `Coordinator<AppRoute>`, never the app's UI).
@Suite("AppDeepLink")
@MainActor
struct DeepLinkTests {
    @Test("appstarter://product/3 parses to .product(id: 3)")
    func parsesProductLink() {
        let url = URL(string: "appstarter://product/3")!
        #expect(AppDeepLink.parse(url) == .product(id: 3))
    }

    @Test("appstarter://search?q=phone parses to .search(query: \"phone\")")
    func parsesSearchLink() {
        let url = URL(string: "appstarter://search?q=phone")!
        #expect(AppDeepLink.parse(url) == .search(query: "phone"))
    }

    @Test("A non-numeric product id fails to parse")
    func rejectsNonNumericProductID() {
        let url = URL(string: "appstarter://product/abc")!
        #expect(AppDeepLink.parse(url) == nil)
    }

    @Test("A search link with no q parameter fails to parse")
    func rejectsSearchWithoutQuery() {
        let url = URL(string: "appstarter://search")!
        #expect(AppDeepLink.parse(url) == nil)
    }

    @Test("A search link with an empty q parameter fails to parse")
    func rejectsSearchWithEmptyQuery() {
        let url = URL(string: "appstarter://search?q=")!
        #expect(AppDeepLink.parse(url) == nil)
    }

    @Test("An unknown host fails to parse")
    func rejectsUnknownHost() {
        let url = URL(string: "appstarter://unknown/3")!
        #expect(AppDeepLink.parse(url) == nil)
    }

    @Test("A different scheme fails to parse")
    func rejectsDifferentScheme() {
        let url = URL(string: "https://appstarter.example/product/3")!
        #expect(AppDeepLink.parse(url) == nil)
    }

    @Test("appstarter://product/3 replaces the whole stack with [.products, .productDetail(id: 3)]")
    func productLinkSetsStack() {
        let coordinator = Coordinator<AppRoute>(root: .login)
        coordinator.push(.favorites)

        let handled = coordinator.handleAppDeepLink(URL(string: "appstarter://product/3")!)

        #expect(handled)
        #expect(coordinator.mainStack.path == [.products, .productDetail(id: 3)])
    }

    @Test("appstarter://search?q=phone presents Search as a sheet, pre-filled")
    func searchLinkPresentsSheet() {
        let coordinator = Coordinator<AppRoute>(root: .products)

        let handled = coordinator.handleAppDeepLink(URL(string: "appstarter://search?q=phone")!)

        #expect(handled)
        #expect(coordinator.sheetStack?.root == .search(query: "phone"))
    }

    @Test("An unparseable URL is not handled and leaves navigation untouched")
    func unparseableURLIsIgnored() {
        let coordinator = Coordinator<AppRoute>(root: .products)

        let handled = coordinator.handleAppDeepLink(URL(string: "appstarter://unknown")!)

        #expect(!handled)
        #expect(coordinator.mainStack.path.isEmpty)
        #expect(coordinator.sheetStack == nil)
    }
}
