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
        let cart = Cart(lines: [.fixture()], total: 12, discountedTotal: 10, totalQuantity: 1)
        #expect(!cart.isEmpty)
    }

    @Test("El total del carrito es el de la API, no la suma de las líneas")
    func totalComesFromTheAPI() {
        // Se construye a propósito con líneas que NO suman el total: si alguien cambiara
        // `discountedTotal` por una suma calculada, este test se pondría rojo.
        let cart = Cart(
            lines: [.fixture(discountedTotal: 10), .fixture(id: 2, discountedTotal: 10)],
            total: 20,
            discountedTotal: 17.5,
            totalQuantity: 4
        )
        #expect(cart.discountedTotal == 17.5)
    }

    // MARK: - El descuento

    @Test("El descuento de una línea es la resta, en crudo")
    func discountAmountIsTheDifference() {
        let line = CartLine.fixture(total: 119.96, discountedTotal: 105.41)
        // Tolerancia de céntimo: la resta en `Double` da 14.549999…, y es a propósito que
        // no se corte aquí — lo redondea el formateador de moneda al pintar `14,55 $`.
        #expect(abs(line.discountAmount - 14.55) < 0.01)
    }

    @Test("Sin rebaja, la resta es exactamente cero")
    func discountAmountIsZeroWithoutDiscount() {
        let line = CartLine.fixture(total: 119.96, discountedTotal: 119.96)
        #expect(line.discountAmount == 0)
    }

    @Test("Dos importes idénticos no son una rebaja")
    func noDiscountWhenAmountsAreIdentical() {
        #expect(CartLine.fixture(total: 119.96, discountedTotal: 119.96).hasDiscount == false)
        #expect(
            Cart(lines: [], total: 119.96, discountedTotal: 119.96, totalQuantity: 0)
                .hasDiscount == false
        )
    }

    @Test("Una diferencia por debajo del céntimo tampoco es una rebaja")
    func noDiscountBelowOneCent() {
        // El caso que `==` sobre `Double` daría por bueno: la pantalla tacharía un
        // `119,96 $` idéntico al de al lado y enseñaría «Descuento −0,00 $». La frontera se
        // mide sobre la cifra que se VE, no sobre el doble en crudo.
        #expect(CartLine.fixture(total: 119.96, discountedTotal: 119.9601).hasDiscount == false)
        #expect(
            Cart(lines: [], total: 119.96, discountedTotal: 119.9601, totalQuantity: 0)
                .hasDiscount == false
        )
    }

    @Test("Un céntimo entero SÍ es una rebaja, y tiene que verse")
    func oneWholeCentIsADiscount() {
        // El otro lado de la frontera. Sin este test, «no decorar por debajo del céntimo»
        // se podría implementar como «no decorar rebajas pequeñas» y nadie se enteraría.
        #expect(CartLine.fixture(total: 119.96, discountedTotal: 119.95).hasDiscount)
        #expect(
            Cart(lines: [], total: 119.96, discountedTotal: 119.95, totalQuantity: 0)
                .hasDiscount
        )
    }

    @Test("Un importe que SUBE no es una rebaja")
    func aSurchargeIsNotADiscount() {
        // `hasDiscount` es direccional. Con una comparación simétrica de «difieren», la fila
        // tachaba el importe menor ENCIMA del mayor y el pie escribía «Descuento −-US$5.00»,
        // con el signo del formateador pegado al nuestro: un recargo con la decoración de una
        // rebaja, que dice lo contrario de lo que pasa.
        #expect(CartLine.fixture(total: 100.00, discountedTotal: 105.00).hasDiscount == false)
        #expect(CartLine.fixture(total: 119.96, discountedTotal: 119.97).hasDiscount == false)
        #expect(
            Cart(lines: [], total: 100.00, discountedTotal: 105.00, totalQuantity: 0)
                .hasDiscount == false
        )
    }

    @Test("Dos importes que se pintan iguales no son una rebaja, aunque difieran en el doble")
    func noDiscountWhenBothRenderTheSame() {
        // `1620.125` y `1620.12` se pintan los dos como `US$1,620.12`. Con `(x*100).rounded()`
        // esto daba `true` y la fila tachaba un importe idéntico al de abajo — la cláusula 3
        // incumplida por el mismo desajuste de redondeo que la frontera existe para evitar.
        // El error lo mete el `× 100` en binario, así que se redondea sobre la representación
        // decimal corta y con half-even, como el formateador.
        #expect(CartLine.fixture(total: 1620.125, discountedTotal: 1620.12).hasDiscount == false)
        #expect(CartLine.fixture(total: 0.125, discountedTotal: 0.12).hasDiscount == false)
    }

    @Test("Un importe que no cabe en `Decimal` no se decora como rebaja")
    func unrepresentableAmountIsNotADiscount() {
        // `JSONDecoder` acepta `1e300` sin rechistar. Con el fallback anterior
        // (`?? Decimal(amount)`) esto daba NaN, y `NaN < finito` es `true` en `Decimal`
        // —al revés que en IEEE—, así que un recargo absurdo volvía a pintarse como rebaja
        // y con el doble signo en el pie. Fuera de rango: no se decora.
        #expect(CartLine.fixture(total: 105.41, discountedTotal: 1e300).hasDiscount == false)
        #expect(CartLine.fixture(total: 1e300, discountedTotal: 105.41).hasDiscount == false)
        #expect(
            Cart(lines: [], total: 1e300, discountedTotal: 105.41, totalQuantity: 0)
                .hasDiscount == false
        )
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
        total: Double = 119.96,
        discountedTotal: Double = 105.41,
        thumbnailURL: URL? = nil
    ) -> CartLine {
        CartLine(
            id: id,
            title: title,
            unitPrice: unitPrice,
            quantity: quantity,
            total: total,
            discountedTotal: discountedTotal,
            thumbnailURL: thumbnailURL
        )
    }
}
