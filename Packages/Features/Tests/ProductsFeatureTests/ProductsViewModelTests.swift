import AppFoundation
import Domain
import Foundation
import Observation
import PlatformTestSupport
import Testing

@testable import ProductsFeature

@Suite("ProductsViewModel")
@MainActor
struct ProductsViewModelTests {
    @Test("handle(.load) calls logic.loadPage(skip: 0) and reaches .content")
    func loadReachesContent() async {
        let mock = ProductsLogicMock()
        let product = Product(id: 1, title: "A", description: "", price: 1, rating: 1, thumbnailURL: nil)
        mock.pageToReturn = ProductsPage(items: [product], total: 1, skip: 0, limit: 20)
        let router = Coordinator<AppRoute>(root: .products)
        let viewModel = ProductsViewModel(logic: mock, router: router)

        viewModel.handle(.load)
        await viewModel.inFlightLoad?.value

        #expect(await mock.loadPageCalls.calls == [0])
        #expect(viewModel.phase == .content)
        #expect(viewModel.items == [product])
    }

    @Test(".load only runs once — a second .load with items already present is a no-op")
    func loadOnlyRunsOnce() async {
        let mock = ProductsLogicMock()
        mock.pageToReturn = ProductsPage(
            items: [Product(id: 1, title: "A", description: "", price: 1, rating: 1, thumbnailURL: nil)],
            total: 1,
            skip: 0,
            limit: 20
        )
        let viewModel = ProductsViewModel(logic: mock, router: Coordinator(root: .products))

        viewModel.handle(.load)
        await viewModel.inFlightLoad?.value
        viewModel.handle(.load)
        await viewModel.inFlightLoad?.value

        #expect(await mock.loadPageCalls.count == 1)
    }

    @Test(".selectProduct pushes .productDetail(id:)")
    func selectProductPushesDetail() {
        let mock = ProductsLogicMock()
        let router = Coordinator<AppRoute>(root: .products)
        let viewModel = ProductsViewModel(logic: mock, router: router)

        viewModel.handle(.selectProduct(id: 42))

        #expect(router.mainStack.path == [.productDetail(id: 42)])
    }

    @Test(".openSearch presents .search as a sheet")
    func openSearchPresentsSheet() {
        let mock = ProductsLogicMock()
        let router = Coordinator<AppRoute>(root: .products)
        let viewModel = ProductsViewModel(logic: mock, router: router)

        viewModel.handle(.openSearch)

        #expect(router.sheetStack?.root == .search(query: nil))
    }

    @Test(".loadMore appends the next page when canLoadMore")
    func loadMoreAppendsNextPage() async {
        let mock = ProductsLogicMock()
        let first = Product(id: 1, title: "A", description: "", price: 1, rating: 1, thumbnailURL: nil)
        let second = Product(id: 2, title: "B", description: "", price: 2, rating: 2, thumbnailURL: nil)
        mock.pageToReturn = ProductsPage(items: [first], total: 2, skip: 0, limit: 1)
        let viewModel = ProductsViewModel(logic: mock, router: Coordinator(root: .products))

        viewModel.handle(.load)
        await viewModel.inFlightLoad?.value
        #expect(viewModel.canLoadMore)

        mock.pageToReturn = ProductsPage(items: [second], total: 2, skip: 1, limit: 1)
        viewModel.handle(.loadMore)
        await viewModel.inFlightActivity?.value

        #expect(viewModel.items == [first, second])
        #expect(viewModel.canLoadMore == false)
    }

    @Test("Changing items notifies Observation — ProductsViewModel's own @Observable (docs/INFORME-MULTI.md §11)")
    func changingItemsNotifiesObservation() async {
        let mock = ProductsLogicMock()
        let product = Product(id: 1, title: "A", description: "", price: 1, rating: 1, thumbnailURL: nil)
        mock.pageToReturn = ProductsPage(items: [product], total: 1, skip: 0, limit: 20)
        let viewModel = ProductsViewModel(logic: mock, router: Coordinator(root: .products))
        let flag = ObservationFlag()

        withObservationTracking {
            _ = viewModel.items
        } onChange: {
            flag.fired = true
        }
        viewModel.handle(.load)
        await viewModel.inFlightLoad?.value

        #expect(flag.fired)
    }
}

/// Un reconocedor equivalente al `AppCancellationRecognizer` de `App/`, que este target no
/// puede importar (R13: una `*Feature` no ve el composition root). Que el de verdad
/// reconozca estos casos lo fija `AppTests/CancellationRecognizerTests`; lo que se prueba
/// aquí es la otra mitad: que CON un reconocedor puesto la pantalla no muestra error, y que
/// SIN él sí lo muestra — o sea, que la pieza es carga estructural y no decoración.

/// Reconoce la cancelación por el NOMBRE DEL CASO, no por el tipo, y **no se restaura**.
/// Las dos cosas son deliberadas y costaron un rato entenderlas:
///
/// `BaseViewModel.cancellationRecognizer` es un `static var` compartido por todo el proceso
/// de test, y las suites de features corren en PARALELO. Un reconocedor atado a un solo
/// tipo hace fallar a la suite gemela; y restaurarlo en un `defer` es peor todavía, porque
/// la que termina antes devuelve el `static` a su valor original mientras la otra sigue en
/// vuelo. Fallos intermitentes que no son del código.
///
/// Reconociendo por nombre de caso —los dos se llaman `cancelled`— e instalándolo una sola
/// vez sin devolverlo, da igual cuál de las dos suites gane la carrera: el valor instalado
/// es equivalente. `.serialized` no bastaba: solo ordena DENTRO de una suite.
///
/// Lo que NO cubre esto es el `AppCancellationRecognizer` de verdad — este target no puede
/// importar `App/` (R13). De ese se encarga `AppTests/CancellationRecognizerTests`.
private struct RecognizerDePrueba: CancellationRecognizing {
    func isCancellation(_ error: any Error) -> Bool { String(describing: error) == "cancelled" }
}

@Suite("ProductsViewModel: una cancelación no llega a la pantalla", .serialized)
@MainActor
struct ProductsViewModelCancellationTests {
    init() { BaseViewModel.cancellationRecognizer = RecognizerDePrueba() }

    @Test("una carga cancelada deja la pantalla en un estado del que se puede salir")
    func cargaCancelada() async {
        let mock = ProductsLogicMock()
        mock.errorToThrow = ProductsError.cancelled
        let vm = ProductsViewModel(logic: mock, router: Coordinator(root: .products))

        vm.handle(.load)
        await vm.inFlightLoad?.value

        // `hasError == false` NO basta: también es cierto con la pantalla colgada en
        // `.loading(.fullScreen)` para siempre, que es el fallo que este cambio estuvo a
        // punto de introducir. Lo que se fija es que se pueda SALIR del estado.
        #expect(vm.hasError == false)
        #expect(vm.isLoading == false)
        #expect(vm.isIdle)
    }

    @Test("un refresco cancelado no deja el overlay puesto para siempre")
    func refrescoCancelado() async {
        let mock = ProductsLogicMock()
        mock.errorToThrow = ProductsError.cancelled
        let vm = ProductsViewModel(logic: mock, router: Coordinator(root: .products))

        vm.handle(.refresh)
        await vm.inFlightActivity?.value

        #expect(vm.isPerformingActivity == false)
        #expect(vm.hasError == false)
    }

    @Test("una paginación cancelada no mata la paginación para siempre")
    func paginacionCancelada() async {
        let mock = ProductsLogicMock()
        let p = Product(id: 1, title: "A", description: "", price: 1, rating: 1, thumbnailURL: nil)
        mock.pageToReturn = ProductsPage(items: [p], total: 100, skip: 0, limit: 20)
        let vm = ProductsViewModel(logic: mock, router: Coordinator(root: .products))
        vm.handle(.load)
        await vm.inFlightLoad?.value

        mock.errorToThrow = ProductsError.cancelled
        vm.handle(.loadMore)
        await vm.inFlightActivity?.value

        // Si el overlay se queda puesto, el `guard !isPerformingActivity` de `loadMore` no
        // vuelve a pasar NUNCA: la lista deja de paginar el resto de la sesión.
        #expect(vm.isPerformingActivity == false)
        #expect(vm.canLoadMore == true)
    }

    @Test("un error de verdad SÍ llega a la pantalla — el reconocedor no se lo come todo")
    func errorDeVerdadSeVe() async {
        let mock = ProductsLogicMock()
        mock.errorToThrow = ProductsError.server
        let vm = ProductsViewModel(logic: mock, router: Coordinator(root: .products))

        vm.handle(.load)
        await vm.inFlightLoad?.value

        #expect(vm.hasError == true)
    }
}

/// La primera actividad se queda esperando a que la cancelen y sale por `.cancelled`; la
/// segunda cuelga en vuelo. Reproduce que `performActivity` cancela la anterior al arrancar.
private final class LogicDeActividadQueSeSolapa: ProductsLogicProtocol, @unchecked Sendable {
    let pageSize = 20
    private(set) var llamadas = 0
    private var primera = true
    /// Cuando es `true`, la PRIMERA llamada devuelve una página con más por cargar (para
    /// poder llegar a `loadMore`) y el solapamiento empieza en la segunda.
    private var cargaInicialPendiente: Bool

    init(primeraCargaConMas: Bool = false) { cargaInicialPendiente = primeraCargaConMas }

    func loadPage(skip: Int) async throws -> ProductsPage {
        llamadas += 1
        if cargaInicialPendiente {
            cargaInicialPendiente = false
            llamadas -= 1                       // esta no cuenta para el solapamiento
            let p = Product(id: 1, title: "A", description: "", price: 1, rating: 1, thumbnailURL: nil)
            return ProductsPage(items: [p], total: 100, skip: 0, limit: 20)
        }
        if primera {
            primera = false
            while !Task.isCancelled { await Task.yield() }
            throw ProductsError.cancelled
        }
        while !Task.isCancelled { await Task.yield() }
        return ProductsPage(items: [], total: 0, skip: 0, limit: 20)
    }
}

@Suite("ProductsViewModel: una actividad superada no pisa a la que la superó", .serialized)
@MainActor
struct ProductsViewModelSolapamientoTests {
    init() { BaseViewModel.cancellationRecognizer = RecognizerDePrueba() }

    @Test("una carga superada por otra no le quita el spinner a la nueva")
    func cargaSuperadaNoPisaALaNueva() async {
        let logic = LogicDeActividadQueSeSolapa()
        let vm = ProductsViewModel(logic: logic, router: Coordinator(root: .products))

        vm.handle(.load)                        // T1, esperando a que la cancelen
        #expect(vm.isLoading)

        // El `guard items.isEmpty` de `load()` NO impide esto: mientras T1 está en vuelo,
        // `items` sigue vacío, así que el segundo `.load` pasa y cancela a T1. Y pasa en la
        // app de verdad — `ProductsView` hace `.onAppear { send(.load) }`.
        vm.handle(.load)                        // T2 cancela T1
        while logic.llamadas < 2 { await Task.yield() }

        #expect(vm.isLoading, "la carga en vuelo perdió su spinner por culpa de la superada")

        vm.inFlightLoad?.cancel()
    }

    @Test("el refresco cancelado por otro no le quita el overlay al nuevo")
    func refrescoSuperadoNoPisaAlNuevo() async {
        let logic = LogicDeActividadQueSeSolapa()
        let vm = ProductsViewModel(logic: logic, router: Coordinator(root: .products))

        vm.handle(.refresh)                     // A1, esperando a que la cancelen
        #expect(vm.isPerformingActivity)

        vm.handle(.refresh)                     // A2 cancela A1
        while logic.llamadas < 2 { await Task.yield() }

        // A1 se desenrolla con `.cancelled`. Sin el `if !Task.isCancelled`, su
        // `stopActivity()` le quita el overlay a A2, que sigue en vuelo — y reabre el
        // `guard !isPerformingActivity` de `loadMore` mientras hay actividad de verdad.
        #expect(vm.isPerformingActivity, "la actividad en vuelo perdió su overlay por la superada")

        vm.inFlightActivity?.cancel()
    }

    @Test("una paginación superada por un refresco tampoco le quita el overlay")
    func paginacionSuperadaPorRefresco() async {
        // `canLoadMore` no es asignable desde fuera: se consigue con una carga previa que
        // devuelva más páginas.
        let logic = LogicDeActividadQueSeSolapa(primeraCargaConMas: true)
        let vm = ProductsViewModel(logic: logic, router: Coordinator(root: .products))
        vm.handle(.load)
        await vm.inFlightLoad?.value
        #expect(vm.canLoadMore)

        vm.handle(.loadMore)                    // A1
        #expect(vm.isPerformingActivity)

        vm.handle(.refresh)                     // A2 cancela A1 — `refresh` no mira isPerformingActivity
        while logic.llamadas < 2 { await Task.yield() }

        #expect(vm.isPerformingActivity, "el refresco en vuelo perdió su overlay por la paginación superada")

        vm.inFlightActivity?.cancel()
    }
}

