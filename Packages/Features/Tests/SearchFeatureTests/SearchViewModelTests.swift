import AppFoundation
import AppFoundationTestSupport
import Domain
import Foundation
import Observation
import PlatformTestSupport
import Testing

@testable import SearchFeature

/// Yields until `condition` holds — no real sleeps. Same idiom as
/// `AppFoundationTests.DebouncerTests`' own `settle(until:)`, `async` here (not just
/// `@MainActor`) because the condition itself reads `SpyRecorder` (an actor) — polling a
/// SYNCHRONOUS condition like `inFlightLoad != nil` would race: nothing sets
/// `inFlightLoad` until the debounced `Task` itself gets scheduled after
/// `ManualClock.advance(by:)`, so there is no safe synchronous instant to observe it
/// transition from `nil`. Polling the actual side effect (a recorded call) has no such
/// window.
private func settle(until condition: () async -> Bool) async {
    for _ in 0..<10_000 {
        if await condition() { return }
        await Task.yield()
    }
}

@Suite("SearchViewModel")
@MainActor
struct SearchViewModelTests {
    @Test("handle(.submit) calls logic.search and reaches .content")
    func submitReachesContent() async {
        let mock = SearchLogicMock()
        let product = Product(id: 1, title: "Phone", description: "", price: 1, rating: 1, thumbnailURL: nil)
        mock.resultsToReturn = [product]
        let viewModel = SearchViewModel(logic: mock, router: Coordinator(root: .products))

        viewModel.handle(.updateQuery("phone"))
        viewModel.handle(.submit)
        await viewModel.inFlightLoad?.value

        #expect(await mock.searchCalls.calls == ["phone"])
        #expect(viewModel.phase == .content)
        #expect(viewModel.results == [product])
    }

    @Test("handle(.updateQuery) debounces — the Logic isn't called until the window elapses")
    func updateQueryDebouncesBeforeSearching() async {
        let clock = ManualClock()
        let mock = SearchLogicMock()
        mock.resultsToReturn = []
        let viewModel = SearchViewModel(logic: mock, router: Coordinator(root: .products), clock: clock)

        viewModel.handle(.updateQuery("phone"))
        #expect(await mock.searchCalls.calls.isEmpty, "the Logic must not be called before the debounce window elapses")

        await clock.waitUntilSleeping()
        clock.advance(by: .milliseconds(300))
        await settle { !(await mock.searchCalls.calls.isEmpty) }

        #expect(await mock.searchCalls.calls == ["phone"])
    }

    @Test("Rapid handle(.updateQuery) calls coalesce into a single search for the LAST query")
    func rapidUpdateQueryCoalescesIntoOneSearch() async {
        let clock = ManualClock()
        let mock = SearchLogicMock()
        mock.resultsToReturn = []
        let viewModel = SearchViewModel(logic: mock, router: Coordinator(root: .products), clock: clock)

        viewModel.handle(.updateQuery("p"))
        viewModel.handle(.updateQuery("ph"))
        viewModel.handle(.updateQuery("phone"))

        await clock.waitUntilSleeping()
        clock.advance(by: .milliseconds(300))
        await settle { !(await mock.searchCalls.calls.isEmpty) }

        #expect(await mock.searchCalls.calls == ["phone"])
    }

    @Test("handle(.submit) bypasses the debounce and searches immediately")
    func submitBypassesDebounce() async {
        let clock = ManualClock()
        let mock = SearchLogicMock()
        let product = Product(id: 1, title: "Phone", description: "", price: 1, rating: 1, thumbnailURL: nil)
        mock.resultsToReturn = [product]
        let viewModel = SearchViewModel(logic: mock, router: Coordinator(root: .products), clock: clock)

        viewModel.handle(.updateQuery("phone"))
        viewModel.handle(.submit)
        await viewModel.inFlightLoad?.value

        #expect(await mock.searchCalls.calls == ["phone"])
        #expect(viewModel.results == [product])
        // The debounce this cancelled never fires: advancing the clock past its window
        // must not trigger a SECOND search.
        clock.advance(by: .milliseconds(300))
        await Task.yield()
        #expect(await mock.searchCalls.calls == ["phone"])
    }

    @Test("An empty query clears results without calling the logic")
    func emptyQueryClearsResults() async {
        let mock = SearchLogicMock()
        let viewModel = SearchViewModel(logic: mock, router: Coordinator(root: .products))

        viewModel.handle(.updateQuery(""))

        #expect(await mock.searchCalls.calls.isEmpty)
        #expect(viewModel.results.isEmpty)
    }

    @Test("An initialQuery seeds query and handle(.appear) submits it once")
    func initialQueryAutoSubmits() async {
        let mock = SearchLogicMock()
        let product = Product(id: 1, title: "Phone", description: "", price: 1, rating: 1, thumbnailURL: nil)
        mock.resultsToReturn = [product]
        let viewModel = SearchViewModel(logic: mock, router: Coordinator(root: .products), initialQuery: "phone")

        #expect(viewModel.query == "phone")
        viewModel.handle(.appear)
        await viewModel.inFlightLoad?.value

        #expect(await mock.searchCalls.calls == ["phone"])
        #expect(viewModel.results == [product])
    }

    @Test("A nil initialQuery (plain \"open search\") never auto-submits on appear")
    func nilInitialQueryDoesNotAutoSubmit() {
        let mock = SearchLogicMock()
        let viewModel = SearchViewModel(logic: mock, router: Coordinator(root: .products))

        viewModel.handle(.appear)

        #expect(viewModel.query.isEmpty)
        #expect(viewModel.phase == .idle)
    }

    @Test("handle(.selectProduct) dismisses the sheet and pushes the detail")
    func selectProductDismissesAndPushes() {
        let mock = SearchLogicMock()
        let router = Coordinator<AppRoute>(root: .products)
        router.present(.search(query: nil), as: .sheet)
        let viewModel = SearchViewModel(logic: mock, router: router)

        viewModel.handle(.selectProduct(id: 5))

        #expect(router.modal == nil)
        #expect(router.mainStack.path == [.productDetail(id: 5)])
    }

    @Test("Changing query notifies Observation — SearchViewModel declares its own @Observable (§11)")
    func changingQueryNotifiesObservation() {
        let mock = SearchLogicMock()
        let viewModel = SearchViewModel(logic: mock, router: Coordinator(root: .products))
        let flag = ObservationFlag()

        withObservationTracking {
            _ = viewModel.query
        } onChange: {
            flag.fired = true
        }
        viewModel.handle(.updateQuery("phone"))

        #expect(flag.fired)
    }
}

/// Equivalente al `AppCancellationRecognizer` de `App/`, que este target no puede importar
/// (R13). Ver la nota del gemelo en `ProductsViewModelTests`.

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

@Suite("SearchViewModel: una cancelación no llega a la pantalla", .serialized)
@MainActor
struct SearchViewModelCancellationTests {
    init() { BaseViewModel.cancellationRecognizer = RecognizerDePrueba() }

    @Test("una búsqueda cancelada no cuelga la hoja")
    func busquedaCancelada() async {
        let mock = SearchLogicMock()
        mock.errorToThrow = SearchError.cancelled
        let vm = SearchViewModel(logic: mock, router: Coordinator(root: .products))

        vm.handle(.updateQuery("phone"))
        vm.handle(.submit)
        await vm.inFlightLoad?.value

        #expect(vm.hasError == false)
        #expect(vm.isLoading == false)
        #expect(vm.isIdle)
    }
}

/// La primera llamada se queda esperando hasta que su `Task` se cancele y sale por
/// `.cancelled`; la segunda cuelga hasta que la suelten. Reproduce el solapamiento real:
/// `performLoad` cancela la carga anterior al arrancar la nueva.
private final class LogicQueSeSolapa: SearchLogicProtocol, @unchecked Sendable {
    private(set) var llamadas = 0
    private var primera = true

    func search(query: String) async throws -> [Product] {
        llamadas += 1
        if primera {
            primera = false
            while !Task.isCancelled { await Task.yield() }
            throw SearchError.cancelled
        }
        while !Task.isCancelled { await Task.yield() }   // la segunda se queda en vuelo
        return []
    }
}

@Suite("SearchViewModel: una carga superada no pisa a la que la superó", .serialized)
@MainActor
struct SearchViewModelSolapamientoTests {
    init() { BaseViewModel.cancellationRecognizer = RecognizerDePrueba() }

    @Test("la búsqueda cancelada por otra no le quita el spinner a la nueva")
    func superadaNoPisaALaNueva() async {
        let logic = LogicQueSeSolapa()
        let vm = SearchViewModel(logic: logic, router: Coordinator(root: .products))

        vm.handle(.updateQuery("a"))
        vm.handle(.submit)                    // T1, se queda esperando
        #expect(vm.isLoading)

        vm.handle(.updateQuery("ab"))
        vm.handle(.submit)                    // T2 cancela T1
        while logic.llamadas < 2 { await Task.yield() }

        // T1 se desenrolla con `.cancelled`. Sin el `if !Task.isCancelled`, su `setIdle()`
        // le quita el spinner a T2, que sigue cargando.
        #expect(vm.isLoading, "la carga en vuelo perdió su spinner por culpa de la superada")

        vm.inFlightLoad?.cancel()
    }
}
