import CoreNetworking
import CoreNetworkingTestSupport
import Foundation

/// Recorded DummyJSON responses for `-UITestOffline` (PRD-APP-01: "CI sin red o sin
/// depender del servicio"). `InMemoryTransport` is normally test-only
/// (`CoreNetworkingTestSupport`, never in a production binary per that package's own
/// `AGENTS.md`) — this app links it into every configuration anyway, the same accepted
/// trade-off `AppFoundation/Examples/LoginApp`'s `Package.swift` documents for its own
/// preview target: SwiftPM's target-dependency conditions don't support a build-
/// configuration case. See `docs/INFORME-INTEGRACION.md`.
enum OfflineFixtures {
    static let baseURL = URL(string: "https://dummyjson.com")!

    /// The one product every offline fixture uses — `Products` lists it, `ProductDetail`
    /// fetches it by id, `Search` finds it by title.
    static let productID = 1
    static let productTitle = "Essence Mascara Lash Princess"

    /// Synchronous on purpose: `AppStarterApp.init()` (a SwiftUI `App`) can't be `async`,
    /// but every exchange must be registered on `transport` BEFORE `RootView` renders and
    /// the app's first request goes out — `InMemoryTransport.register(_:)` is `async`
    /// (it's an `actor`). A `DispatchSemaphore` bridges the two: the `Task` below runs on
    /// the cooperative thread pool while this (main) thread blocks briefly waiting for it,
    /// which is safe here because nothing the `Task` does needs the main actor.
    static func makeTransport() -> InMemoryTransport {
        let transport = InMemoryTransport()
        let semaphore = DispatchSemaphore(value: 0)

        Task {
            await transport.register(
                InMemoryTransport.Exchange(
                    method: .post,
                    url: baseURL.appendingPathComponent("auth/login"),
                    response: .response(status: 200, body: loginBody)
                )
            )
            await transport.register(
                InMemoryTransport.Exchange(
                    method: .get,
                    url: baseURL.appendingPathComponent("products").withQuery([("limit", "20"), ("skip", "0")]),
                    response: .response(status: 200, body: productsPageBody)
                )
            )
            await transport.register(
                InMemoryTransport.Exchange(
                    method: .get,
                    url: baseURL.appendingPathComponent("products/\(productID)"),
                    response: .response(status: 200, body: productBody)
                )
            )
            await transport.register(
                InMemoryTransport.Exchange(
                    method: .get,
                    url: baseURL.appendingPathComponent("products/search").withQuery([("q", "mascara")]),
                    response: .response(status: 200, body: searchBody)
                )
            )
            await transport.register(
                InMemoryTransport.Exchange(
                    method: .get,
                    url: baseURL.appendingPathComponent("auth/me"),
                    response: .response(status: 200, body: meBody)
                )
            )
            semaphore.signal()
        }

        semaphore.wait()
        return transport
    }

    private static let loginBody = Data(
        """
        {"accessToken":"offline-access","refreshToken":"offline-refresh","id":1,"username":"emilys","email":"emily.johnson@x.dummyjson.com","firstName":"Emily","lastName":"Johnson","image":"https://dummyjson.com/icon/emilys/128"}
        """
        .utf8
    )

    private static let productsPageBody = Data(
        """
        {"products":[{"id":\(productID),"title":"\(productTitle)","description":"A popular mascara known for its volumizing and lengthening effects.","price":9.99,"rating":2.56,"thumbnail":"https://cdn.dummyjson.com/products/images/beauty/Essence%20Mascara%20Lash%20Princess/thumbnail.png"}],"total":1,"skip":0,"limit":20}
        """
        .utf8
    )

    private static let productBody = Data(
        """
        {"id":\(productID),"title":"\(productTitle)","description":"A popular mascara known for its volumizing and lengthening effects.","price":9.99,"rating":2.56,"thumbnail":"https://cdn.dummyjson.com/products/images/beauty/Essence%20Mascara%20Lash%20Princess/thumbnail.png"}
        """
        .utf8
    )

    private static let searchBody = Data(
        """
        {"products":[{"id":\(productID),"title":"\(productTitle)","description":"A popular mascara known for its volumizing and lengthening effects.","price":9.99,"rating":2.56,"thumbnail":"https://cdn.dummyjson.com/products/images/beauty/Essence%20Mascara%20Lash%20Princess/thumbnail.png"}]}
        """
        .utf8
    )

    private static let meBody = Data(
        """
        {"id":1,"username":"emilys","email":"emily.johnson@x.dummyjson.com","firstName":"Emily","lastName":"Johnson","image":"https://dummyjson.com/icon/emilys/128"}
        """
        .utf8
    )
}

private extension URL {
    func withQuery(_ items: [(String, String)]) -> URL {
        var components = URLComponents(url: self, resolvingAgainstBaseURL: false)!
        components.queryItems = items.map { URLQueryItem(name: $0.0, value: $0.1) }
        return components.url!
    }
}
