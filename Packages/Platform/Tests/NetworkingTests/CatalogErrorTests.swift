import CoreNetworking
import CoreNetworkingTestSupport
import Foundation
import Networking
import Testing

/// Lo que `CatalogError` promete, comprobado UNA vez.
///
/// Vive aquí y no en cada feature a propósito: cuando `ProductsError` y `SearchError` eran dos
/// tipos, cada feature tenía su propio test de `isRetryable` y los dos decían lo mismo. Al
/// fundirlos, esos dos tests pasaron a tener el mismo cuerpo — el detector de lógica repetida
/// lo reportó como un grupo nuevo, introducido por el propio cambio que venía a quitar tres.
/// La aserción sobre el tipo se hace donde vive el tipo; lo que queda en cada feature es que su
/// `Logic` traduzca de verdad el fallo del transporte.
@Suite("CatalogError")
struct CatalogErrorTests {
    @Test("una cancelación NO es reintentable, el resto sí")
    func cancelacionNoEsReintentable() {
        #expect(CatalogError.cancelled.isRetryable == false)
        #expect(CatalogError.server.isRetryable == true)
        #expect(CatalogError.offline.isRetryable == true)
        #expect(CatalogError.unknown.isRetryable == true)
    }

    @Test("el mapeo desde APIError respeta la cancelación")
    func mapeoDesdeAPIError() {
        #expect(CatalogError.from(.stub(code: .cancelled, underlying: URLError(.cancelled))) == .cancelled)
        #expect(CatalogError.from(.stub(code: .httpStatus, statusCode: 500)) == .server)
        #expect(CatalogError.from(.stub(code: .transport, underlying: URLError(.notConnectedToInternet))) == .offline)
    }
}
