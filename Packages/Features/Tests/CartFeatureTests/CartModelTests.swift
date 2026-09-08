import AppFoundation
import Domain
import Foundation
import Testing

@testable import CartFeature

/// El modelo y los errores de la feature: lo que la pantalla distingue y lo que ofrece
/// reintentar. Sin red y sin `Logic` de por medio.
@Suite("Cart · modelo y errores")
struct CartModelTests {
    @Test("Un carrito sin líneas está vacío, y `empty` no suma nada")
    func emptyCartIsEmpty() {
        #expect(Cart.empty.isEmpty)
        #expect(Cart.empty.discountedTotal == 0)
        #expect(Cart.empty.totalQuantity == 0)
    }

    @Test("Un carrito con líneas no está vacío")
    func cartWithLinesIsNotEmpty() {
        let cart = Cart(lines: [.fixture()], discountedTotal: 10, totalQuantity: 1)
        #expect(!cart.isEmpty)
    }

    @Test("El total del carrito es el de la API, no la suma de las líneas")
    func totalComesFromTheAPI() {
        // Se construye a propósito con líneas que NO suman el total: si alguien cambiara
        // `discountedTotal` por una suma calculada, este test se pondría rojo.
        let cart = Cart(
            lines: [.fixture(discountedTotal: 10), .fixture(id: 2, discountedTotal: 10)],
            discountedTotal: 17.5,
            totalQuantity: 4
        )
        #expect(cart.discountedTotal == 17.5)
    }

    @Test("Cancelado y sin carrito no se reintentan; los demás sí")
    func retryability() {
        #expect(CartError.cancelled.isRetryable == false)
        #expect(CartError.notFound.isRetryable == false)
        #expect(CartError.offline.isRetryable)
        #expect(CartError.server.isRetryable)
        #expect(CartError.unknown.isRetryable)
    }

    @Test("Los textos compartidos salen de ErrorCopy, no escritos otra vez aquí")
    func sharedCopyComesFromErrorCopy() {
        // Fija la regla que `ErrorCopy` existe para sostener: si alguien escribe el literal
        // a mano en esta feature, diverge del resto de pantallas sin que nadie se entere.
        #expect(CartError.offline.screenError.title == ErrorCopy.Offline.title)
        #expect(CartError.offline.screenError.message == ErrorCopy.Offline.message)
        #expect(CartError.server.screenError.title == ErrorCopy.Server.title)
        #expect(CartError.unknown.screenError.title == ErrorCopy.Unknown.title)
    }

    @Test("El error de carrito ausente tiene copy propia, distinta del `NotFound` de producto")
    func missingCartHasItsOwnCopy() {
        // `ErrorCopy.NotFound` dice "Este producto ya no está disponible", que aquí sería
        // mentira: lo que no existe es el carrito, no un producto.
        #expect(CartError.notFound.screenError.message != ErrorCopy.NotFound.message)
    }
}

extension CartLine {
    static func fixture(
        id: Int = 1,
        title: String = "Blue Frock",
        unitPrice: Double = 29.99,
        quantity: Int = 4,
        discountedTotal: Double = 105.41,
        thumbnailURL: URL? = nil
    ) -> CartLine {
        CartLine(
            id: id,
            title: title,
            unitPrice: unitPrice,
            quantity: quantity,
            discountedTotal: discountedTotal,
            thumbnailURL: thumbnailURL
        )
    }
}
