import Foundation
import Testing

@testable import CartFeature

/// Lo que oye quien no ve el tachado.
///
/// Estos cuatro tests son la única forma de fijar la cláusula 6 —la del lector de
/// pantalla— del requisito dentro de la
/// firma de verificación: `AppUITests`, que sería el sitio natural, queda fuera por decisión
/// declarada en `kit.conf`. Por eso el texto es una función pura y no un `.accessibilityLabel`
/// compuesto dentro de la vista.
///
/// Se asevera sobre las CIFRAS y las palabras que las separan, no sobre la frase entera:
/// fijar el string completo convertiría cualquier retoque de redacción en un test rojo sin
/// que nada se hubiera roto.
///
/// Y el importe esperado se COMPONE con el formateador, no se escribe a mano: el símbolo de
/// `.currency(code: "USD")` depende del locale de quien corre los tests —`$29.99` en uno,
/// `US$29.99` en otro—, así que un literal a pelo pondría el test rojo al cambiar de
/// máquina. Lo que se fija sigue siendo lo que importa: qué importe va con qué palabra, y
/// que la moneda es la que la pantalla usa.
@Suite("CartCopy · lo que oye VoiceOver")
struct CartCopyTests {
    private func money(_ amount: Double) -> String {
        amount.formatted(.currency(code: "USD"))
    }

    @Test("Una línea con descuento nombra el unitario, el importe anterior y el que se paga")
    func lineWithDiscountNamesAllThree() {
        let texto = CartCopy.lineAccessibilityLabel(
            .fixture(unitPrice: 29.99, quantity: 4, total: 119.96, discountedTotal: 105.41)
        )

        #expect(texto.contains("Blue Frock"))
        #expect(texto.contains("4 por \(money(29.99)) cada uno"))
        #expect(texto.contains("antes \(money(119.96))"))
        #expect(texto.contains("ahora \(money(105.41))"))
    }

    @Test("Una línea sin descuento no nombra ningún importe anterior")
    func lineWithoutDiscountNamesNoPreviousAmount() {
        let texto = CartCopy.lineAccessibilityLabel(
            .fixture(unitPrice: 29.99, quantity: 4, total: 119.96, discountedTotal: 119.96)
        )

        #expect(texto.contains("total \(money(119.96))"))
        // Lo que NO se dice es el requisito: sin rebaja, un «antes» es una rebaja inventada.
        #expect(!texto.contains("antes"))
        #expect(!texto.contains("ahora"))
    }

    @Test("El pie con descuento nombra subtotal, descuento y total")
    func footerWithDiscountNamesTheBreakdown() {
        let texto = CartCopy.totalAccessibilityLabel(
            Cart(lines: [], total: 119.96, discountedTotal: 105.41, totalQuantity: 4)
        )

        #expect(texto.contains("4 artículos"))
        #expect(texto.contains("subtotal \(money(119.96))"))
        // `14.549999…` redondeado por el formateador: lo que se oye es la cifra que se ve.
        #expect(texto.contains("descuento \(money(14.55))"))
        #expect(texto.contains("total \(money(105.41))"))
    }

    @Test("El pie sin descuento dice solo el total")
    func footerWithoutDiscountNamesOnlyTheTotal() {
        let texto = CartCopy.totalAccessibilityLabel(
            Cart(lines: [], total: 105.41, discountedTotal: 105.41, totalQuantity: 4)
        )

        #expect(texto.contains("total \(money(105.41))"))
        #expect(!texto.contains("subtotal"))
        #expect(!texto.contains("descuento"))
    }
}
