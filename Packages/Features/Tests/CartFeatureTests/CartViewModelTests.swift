import AppFoundation
import Foundation
import PlatformTestSupport
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
        Cart(id: 1, lines: lines, total: 119.96, discountedTotal: 105.41, totalQuantity: 4)
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

    // MARK: - Ediciones

    /// El carrito que la pantalla tiene cargado antes de cada edición: dos líneas.
    private static let cargado = Cart(
        id: 1,
        lines: [.fixture(id: 1, quantity: 4), .fixture(id: 2, quantity: 1)],
        total: 119.96,
        discountedTotal: 105.41,
        totalQuantity: 5
    )

    /// Lo que «responde el servidor» a una edición: distinto de `cargado` en todo, para que
    /// quedarse con el carrito de antes —o retocarlo a mano— se note.
    private static let respuesta = Cart(
        id: 1,
        lines: [.fixture(id: 1, quantity: 2, total: 59.98, discountedTotal: 53)],
        total: 59.98,
        discountedTotal: 53,
        totalQuantity: 2
    )

    /// Un view model con `cargado` ya en pantalla, en `.content`.
    private static func conCarrito(_ mock: CartLogicMock) async -> CartViewModel {
        mock.cartToReturn = cargado
        let viewModel = CartViewModel(logic: mock, userId: 1)
        viewModel.handle(.load)
        await viewModel.inFlightLoad?.value
        return viewModel
    }

    @Test("Una edición con éxito enseña el carrito que devolvió la Logic, entero")
    func editShowsTheResponse() async {
        let mock = CartLogicMock()
        let viewModel = await Self.conCarrito(mock)
        mock.editedCartToReturn = Self.respuesta

        viewModel.handle(.setQuantity(2, lineId: 1))
        await viewModel.inFlightActivity?.value

        // A la `Logic` le llega lo que se pidió y sobre el carrito que se veía.
        #expect(mock.setQuantityCalls.first?.quantity == 2)
        #expect(mock.setQuantityCalls.first?.lineId == 1)
        #expect(mock.setQuantityCalls.first?.cart == Self.cargado)
        #expect(viewModel.cart == Self.respuesta)
        #expect(viewModel.phase == .content)
        #expect(viewModel.isPerformingActivity == false)
    }

    @Test("Quitar la última línea deja la pantalla en su estado vacío, sin error")
    func removingTheLastLineReachesEmpty() async {
        let mock = CartLogicMock()
        let viewModel = await Self.conCarrito(mock)
        mock.editedCartToReturn = Cart(id: 1, lines: [], total: 0, discountedTotal: 0, totalQuantity: 0)

        viewModel.handle(.removeLine(id: 1))
        await viewModel.inFlightActivity?.value

        #expect(mock.removeLineCalls.first?.lineId == 1)
        #expect(mock.removeLineCalls.first?.cart == Self.cargado)
        #expect(viewModel.phase == .empty)
        #expect(viewModel.hasError == false)
        #expect(viewModel.isPerformingActivity == false)
    }

    @Test("Una edición que falla deja el carrito como estaba, en .content, sin overlay y con banner")
    func failedEditKeepsTheCart() async {
        let mock = CartLogicMock()
        let viewModel = await Self.conCarrito(mock)
        mock.editErrorToThrow = CartError.server

        viewModel.handle(.setQuantity(2, lineId: 1))
        await viewModel.inFlightActivity?.value

        #expect(viewModel.cart == Self.cargado)
        // `.content`, no `.error`: el fallo no sustituye el carrito por una pantalla de error.
        #expect(viewModel.phase == .content)
        #expect(viewModel.isPerformingActivity == false)
        #expect(viewModel.banner != nil)
    }

    @Test("Mientras el servidor no responde, el carrito no cambia y la pantalla indica que trabaja")
    func nothingChangesBeforeTheResponse() async {
        let mock = CartLogicMock()
        let viewModel = await Self.conCarrito(mock)
        let puerta = Puerta()
        mock.editGate = { _ in await puerta.esperar() }
        mock.editedCartToReturn = Self.respuesta

        viewModel.handle(.setQuantity(2, lineId: 1))
        // Hasta que la `Logic` tiene la petición: entonces sí está «en vuelo».
        while mock.editCallCount < 1 { await Task.yield() }

        #expect(viewModel.cart == Self.cargado)
        #expect(viewModel.isPerformingActivity)

        await puerta.abrir()
        await viewModel.inFlightActivity?.value
        #expect(viewModel.cart == Self.respuesta)
    }

    @Test("Con una edición en vuelo, otra no llega a la Logic")
    func secondEditWhileInFlightIsRefused() async {
        let mock = CartLogicMock()
        let viewModel = await Self.conCarrito(mock)
        let puerta = Puerta()
        // Solo la PRIMERA espera. Si la segunda llegara a arrancar, pasaría de largo y se
        // contaría: es lo que hace rojo este test sin la guardia.
        mock.editGate = { llamada in if llamada == 1 { await puerta.esperar() } }

        viewModel.handle(.setQuantity(2, lineId: 1))
        while mock.editCallCount < 1 { await Task.yield() }

        viewModel.handle(.removeLine(id: 2))
        viewModel.handle(.setQuantity(3, lineId: 1))

        await puerta.abrir()
        // Sin la guardia, `inFlightActivity` sería la ÚLTIMA edición, y esperarla la contaría.
        await viewModel.inFlightActivity?.value

        #expect(mock.editCallCount == 1)
        #expect(mock.removeLineCalls.isEmpty)
    }

    @Test("Después de una edición que falla, la siguiente sí llega")
    func editAfterAFailureGoesThrough() async {
        let mock = CartLogicMock()
        let viewModel = await Self.conCarrito(mock)
        mock.editErrorToThrow = CartError.server

        viewModel.handle(.setQuantity(2, lineId: 1))
        await viewModel.inFlightActivity?.value

        mock.editErrorToThrow = nil
        mock.editedCartToReturn = Self.respuesta
        viewModel.handle(.removeLine(id: 2))
        await viewModel.inFlightActivity?.value

        #expect(mock.editCallCount == 2)
        #expect(viewModel.cart == Self.respuesta)
    }
}

/// Las pruebas de cancelación viven en su propia suite `.serialized` porque instalan
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
        Cart(id: 1, lines: lines, total: 119.96, discountedTotal: 105.41, totalQuantity: 4)
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

    // MARK: - La cancelación de una edición

    /// Un view model con un carrito ya en pantalla, en `.content`.
    private static func conCarrito(_ mock: CartLogicMock) async -> CartViewModel {
        mock.cartToReturn = cart()
        let viewModel = CartViewModel(logic: mock, userId: 1)
        viewModel.handle(.load)
        await viewModel.inFlightLoad?.value
        return viewModel
    }

    @Test("Una edición cancelada desde la red no pinta error ni deja el overlay puesto")
    func cancelledEditDoesNotStrandTheOverlay() async {
        // `performActivity` reconoce la cancelación y sale sin `stopActivity()`. Sin el de la
        // pantalla, el overlay se queda para siempre y la guardia rechaza toda edición.
        let mock = CartLogicMock()
        let viewModel = await Self.conCarrito(mock)
        mock.editErrorToThrow = CartError.cancelled

        viewModel.handle(.setQuantity(2, lineId: 1))
        await viewModel.inFlightActivity?.value

        #expect(viewModel.isPerformingActivity == false)
        #expect(viewModel.banner == nil)
        #expect(viewModel.hasError == false)
        #expect(viewModel.phase == .content)
    }

    @Test("Una edición cuya pantalla ya se retiró no toca el indicador al desenrollarse")
    func editCancelledByRemovalLeavesTheActivityAlone() async {
        // `cancelInFlightWork()` es lo que llama `ScreenContainer` al retirar la vista. La
        // edición se desenrolla después con `.cancelled` y su `Task` YA cancelada: sin el
        // `if !Task.isCancelled`, tocaría la actividad de una pantalla que ya no está.
        let mock = CartLogicMock()
        let viewModel = await Self.conCarrito(mock)
        let puerta = Puerta()
        mock.editGate = { _ in await puerta.esperar() }
        mock.editErrorToThrow = CartError.cancelled

        viewModel.handle(.setQuantity(2, lineId: 1))
        while mock.editCallCount < 1 { await Task.yield() }
        let edicion = viewModel.inFlightActivity

        viewModel.cancelInFlightWork()
        await puerta.abrir()
        await edicion?.value

        #expect(viewModel.isPerformingActivity, "la cancelación tocó la actividad")
        #expect(viewModel.banner == nil)
    }
}

// `RecognizerDePrueba` y `Puerta` viven en `PlatformTestSupport`: los usan varios targets de
// test, y `plataforma` → «Dónde vive un helper de test compartido» prohíbe la copia privada.
