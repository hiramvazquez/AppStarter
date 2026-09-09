import AppFoundation
import Foundation
import Testing

@testable import CartFeature

/// `CartViewModel` solo contra `CartLogicMock` — ni `CartService` ni red.
///
/// Los tests fijan la FASE, no solo si hay error: el fallo que la spec de esta pantalla
/// persigue es quedarse colgado en `.loading`, y eso `hasError == false` no lo detecta.
@Suite("CartViewModel")
@MainActor
struct CartViewModelTests {
    private static func cart(lines: [CartLine] = [.fixture()]) -> Cart {
        Cart(lines: lines, total: 119.96, discountedTotal: 105.41, totalQuantity: 4)
    }

    @Test("Carga con líneas: pide el carrito del usuario y queda en .content")
    func loadReachesContent() async {
        let mock = CartLogicMock()
        mock.cartToReturn = Self.cart()
        let viewModel = CartViewModel(logic: mock, userId: 7)

        viewModel.handle(.load)
        await viewModel.inFlightLoad?.value

        #expect(mock.loadCallCount == 1)
        #expect(mock.lastUserId == 7)
        #expect(viewModel.phase == .content)
        #expect(viewModel.cart.lines.count == 1)
    }

    @Test("Un usuario sin carritos queda en .empty, no en .content ni en error")
    func loadReachesEmpty() async {
        let mock = CartLogicMock()
        mock.cartToReturn = .empty
        let viewModel = CartViewModel(logic: mock, userId: 1)

        viewModel.handle(.load)
        await viewModel.inFlightLoad?.value

        #expect(viewModel.phase == .empty)
        #expect(viewModel.hasError == false)
    }

    @Test("Un fallo de red deja la pantalla en error, no colgada cargando")
    func loadFailureShowsError() async {
        let mock = CartLogicMock()
        mock.errorToThrow = CartError.server
        let viewModel = CartViewModel(logic: mock, userId: 1)

        viewModel.handle(.load)
        await viewModel.inFlightLoad?.value

        #expect(viewModel.hasError)
        #expect(viewModel.isLoading == false)
    }

}

/// Las dos pruebas de cancelación viven en su propia suite `.serialized` porque instalan
/// `BaseViewModel.cancellationRecognizer`, que es un `static var` de todo el proceso: en
/// paralelo, una suite le cambiaría el reconocedor a la otra a mitad de ejecución.
///
/// No se restaura en un `defer` a propósito, por lo mismo: la suite que acabara antes se lo
/// quitaría a la que siguiera en vuelo. Y se reconoce por NOMBRE de caso, no por tipo, para
/// no atarlo a `CartError` y romper a la suite gemela de otra feature.
@Suite("CartViewModel: una cancelación no llega a la pantalla", .serialized)
@MainActor
struct CartViewModelCancellationTests {
    init() { BaseViewModel.cancellationRecognizer = RecognizerDePrueba() }

    private static func cart(lines: [CartLine] = [.fixture()]) -> Cart {
        Cart(lines: lines, total: 119.96, discountedTotal: 105.41, totalQuantity: 4)
    }

    @Test("Una cancelación no deja la pantalla colgada en .loading ni la marca con error")
    func cancellationDoesNotStrandTheScreen() async {
        // El fallo que este test persigue: `performLoad` reconoce la cancelación y sale con
        // un `return` que no toca `phase`, así que sin el `setIdle()` la pantalla se queda
        // en `.loading` para siempre — sin contenido, sin error y sin poder reintentar.
        let mock = CartLogicMock()
        mock.errorToThrow = CartError.cancelled
        let viewModel = CartViewModel(logic: mock, userId: 1)

        viewModel.handle(.load)
        await viewModel.inFlightLoad?.value

        // `hasError == false` NO basta: también es cierto con la pantalla colgada en
        // `.loading` para siempre, que es justo el fallo que persigue este test.
        #expect(viewModel.hasError == false)
        #expect(viewModel.isLoading == false)
        #expect(viewModel.isIdle)
    }

    @Test("Una carga superada por otra no le quita el indicador a la que la superó")
    func supersededLoadDoesNotResetTheWinner() async {
        // La primera carga se queda esperando en la puerta; la segunda la cancela al
        // arrancar. Cuando la primera se desenrolla con `.cancelled`, su `Task` YA está
        // cancelada: sin el `if !Task.isCancelled`, resetearía la fase de la segunda, que
        // sigue en vuelo.
        let mock = CartLogicMock()
        let primeraPuerta = Puerta()
        let segundaPuerta = Puerta()
        // Una puerta por llamada: si las dos compartieran puerta, abrirla soltaría también
        // a la segunda y ya no habría nada "en vuelo" que observar.
        mock.gate = { llamada in
            await (llamada == 1 ? primeraPuerta : segundaPuerta).esperar()
        }
        mock.errorToThrow = CartError.cancelled
        let viewModel = CartViewModel(logic: mock, userId: 1)

        viewModel.handle(.load)
        let primera = viewModel.inFlightLoad

        viewModel.handle(.load)          // cancela la primera y arranca la segunda
        await primeraPuerta.abrir()
        await primera?.value

        #expect(viewModel.isLoading, "la segunda carga sigue en vuelo")

        await segundaPuerta.abrir()      // se suelta para no dejar la Task colgada
        await viewModel.inFlightLoad?.value
    }
}

private struct RecognizerDePrueba: CancellationRecognizing {
    func isCancellation(_ error: any Error) -> Bool { String(describing: error) == "cancelled" }
}

/// Una espera que se abre a mano: deja una carga EN VUELO para poder observar qué le pasa
/// a la fase mientras otra la supera.
private actor Puerta {
    private var continuaciones: [CheckedContinuation<Void, Never>] = []
    private var abierta = false

    func esperar() async {
        if abierta { return }
        await withCheckedContinuation { continuaciones.append($0) }
    }

    func abrir() {
        abierta = true
        for c in continuaciones { c.resume() }
        continuaciones.removeAll()
    }
}
