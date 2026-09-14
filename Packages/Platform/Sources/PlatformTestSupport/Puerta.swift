import Foundation

/// Una espera que se abre a mano: deja una carga EN VUELO para poder observar qué le pasa a la
/// fase mientras otra la supera.
///
/// Vive aquí y no copiada en cada target porque lo exige `plataforma` → «Dónde vive un helper de
/// test compartido». Llegó a estar en tres —Cart, Gallery y ProductDetail—, y el detector de
/// lógica repetida sí la vio: dos grupos, uno por método.
///
/// Se usa una puerta POR LLAMADA: si dos cargas compartieran puerta, abrirla soltaría también a
/// la segunda y ya no habría nada «en vuelo» que observar.
public actor Puerta {
    private var continuaciones: [CheckedContinuation<Void, Never>] = []
    private var abierta = false

    public init() {}

    public func esperar() async {
        if abierta { return }
        await withCheckedContinuation { continuaciones.append($0) }
    }

    public func abrir() {
        abierta = true
        for c in continuaciones { c.resume() }
        continuaciones.removeAll()
    }
}
