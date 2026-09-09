import Foundation

/// Lo que un lector de pantalla oye en la pantalla de carrito.
///
/// Vive FUERA de `CartView` a propósito, y sin depender de SwiftUI. El tachado que distingue el
/// importe anterior del que se paga es una señal exclusivamente visual: para quien usa
/// VoiceOver, la fila pasaría de dos importes ambiguos a tres. Nombrarlos es el requisito
/// (cláusula 6, la del lector de pantalla, de «La rebaja que se aplica se ve»), y un
/// requisito que solo se puede
/// comprobar con un UI test no se comprueba — `kit.conf` deja `AppUITests` fuera de la firma
/// de verificación a propósito. Sacado aquí como función pura, se fija con `#expect`.
///
/// No es una capa: son literales. Por eso no lleva ninguno de los sufijos que clasifica
/// `.archlint.yml` (`ViewModel`/`Logic`/`Service`/`Store`/`Module`) y ninguna regla de capa
/// le aplica.
enum CartCopy {
    /// El importe, en la misma moneda con la que la pantalla lo pinta.
    ///
    /// Comparte el `code: "USD"` a pelo con `CartView` — que la moneda esté escrita a mano
    /// es un problema real y anterior a este fichero, y arreglarlo aquí sería otro cambio.
    /// Lo que sí importa es que el texto que se OYE y el que se VE salgan del mismo
    /// formateo: si divergieran, VoiceOver diría una cifra distinta de la de la pantalla.
    private static func money(_ amount: Double) -> String {
        amount.formatted(.currency(code: "USD"))
    }

    /// Una línea, dicha entera: qué es, a cuánto la unidad, y —solo si hay rebaja— de qué
    /// importe viene y en cuál se queda.
    static func lineAccessibilityLabel(_ line: CartLine) -> String {
        let cabecera = "\(line.title), \(line.quantity) por \(money(line.unitPrice)) cada uno"
        guard line.hasDiscount else {
            return "\(cabecera), total \(money(line.discountedTotal))"
        }
        return "\(cabecera), antes \(money(line.total)), ahora \(money(line.discountedTotal))"
    }

    /// El pie, dicho entero. Con rebaja nombra las tres cifras del desglose; sin rebaja
    /// dice solo el total, porque es lo único que la pantalla enseña.
    static func totalAccessibilityLabel(_ cart: Cart) -> String {
        let unidades = cart.totalQuantity == 1 ? "1 artículo" : "\(cart.totalQuantity) artículos"
        guard cart.hasDiscount else {
            return "\(unidades), total \(money(cart.discountedTotal))"
        }
        return """
            \(unidades), subtotal \(money(cart.total)), \
            descuento \(money(cart.discountAmount)), total \(money(cart.discountedTotal))
            """
    }
}
