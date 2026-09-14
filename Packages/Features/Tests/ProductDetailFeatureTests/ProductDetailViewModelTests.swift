import AppFoundation
import Domain
import Foundation
import Observation
import PlatformTestSupport
import Testing

@testable import ProductDetailFeature

@Suite("ProductDetailViewModel")
@MainActor
struct ProductDetailViewModelTests {
    @Test("handle(.load) calls logic.load(id:) and reaches .content")
    func loadReachesContent() async {
        let mock = ProductDetailLogicMock()
        let product = Product(id: 7, title: "A", description: "d", price: 1, rating: 1, thumbnailURL: nil)
        mock.stateToReturn = ProductDetailState(product: product, isFavorite: true)
        let viewModel = ProductDetailViewModel(logic: mock, productID: 7, router: Coordinator(root: .products))

        viewModel.handle(.load)
        await viewModel.inFlightLoad?.value

        #expect(await mock.loadCalls.calls == [7])
        #expect(viewModel.phase == .content)
        #expect(viewModel.product == product)
        #expect(viewModel.isFavorite)
    }

    @Test("handle(.toggleFavorite) updates isFavorite from the logic's result")
    func toggleFavoriteUpdatesState() async {
        let mock = ProductDetailLogicMock()
        let product = Product(id: 7, title: "A", description: "d", price: 1, rating: 1, thumbnailURL: nil)
        mock.stateToReturn = ProductDetailState(product: product, isFavorite: false)
        mock.toggleResult = true
        let viewModel = ProductDetailViewModel(logic: mock, productID: 7, router: Coordinator(root: .products))

        viewModel.handle(.load)
        await viewModel.inFlightLoad?.value
        viewModel.handle(.toggleFavorite)
        await viewModel.inFlightActivity?.value

        #expect(viewModel.isFavorite)
    }

    @Test("handle(.openGallery) pushes .gallery(productID:)")
    func openGalleryPushesGalleryRoute() {
        let mock = ProductDetailLogicMock()
        let router = Coordinator<AppRoute>(root: .products)
        let viewModel = ProductDetailViewModel(logic: mock, productID: 7, router: router)

        viewModel.handle(.openGallery)

        #expect(router.mainStack.path == [.gallery(productID: 7)])
    }

    @Test("handle(.back) pops the router")
    func backPopsRouter() {
        let mock = ProductDetailLogicMock()
        let router = Coordinator<AppRoute>(root: .products)
        router.push(.productDetail(id: 1))
        let viewModel = ProductDetailViewModel(logic: mock, productID: 1, router: router)

        viewModel.handle(.back)

        #expect(router.mainStack.path.isEmpty)
    }

    @Test(
        "Changing product notifies Observation — ProductDetailViewModel's own @Observable (docs/INFORME-MULTI.md §11)"
    )
    func changingProductNotifiesObservation() async {
        let mock = ProductDetailLogicMock()
        let product = Product(id: 7, title: "A", description: "d", price: 1, rating: 1, thumbnailURL: nil)
        mock.stateToReturn = ProductDetailState(product: product, isFavorite: true)
        let viewModel = ProductDetailViewModel(logic: mock, productID: 7, router: Coordinator(root: .products))
        let flag = ObservationFlag()

        withObservationTracking {
            _ = viewModel.product
        } onChange: {
            flag.fired = true
        }
        viewModel.handle(.load)
        await viewModel.inFlightLoad?.value

        #expect(flag.fired)
    }

    @Test("una carga cancelada deja la pantalla en un estado del que se puede salir")
    func cargaCancelada() async {
        BaseViewModel.cancellationRecognizer = RecognizerDePrueba()
        let mock = ProductDetailLogicMock()
        mock.errorToThrow = ProductDetailError.cancelled
        let viewModel = ProductDetailViewModel(logic: mock, productID: 7, router: Coordinator(root: .products))

        viewModel.handle(.load)
        await viewModel.inFlightLoad?.value

        // `hasError == false` NO basta: también es cierto con la pantalla colgada en
        // `.loading` para siempre. Lo que se fija es que se pueda SALIR del estado.
        #expect(viewModel.hasError == false)
        #expect(viewModel.isLoading == false)
        #expect(viewModel.isIdle)
    }

    @Test("una carga superada no le quita el indicador a la que la superó")
    func cargaSuperadaNoResetealaGanadora() async {
        // La primera carga se queda esperando en la puerta; la segunda la cancela al arrancar.
        // Cuando la primera se desenrolla con `.cancelled`, su `Task` YA está cancelada: sin el
        // `if !Task.isCancelled` del ViewModel, resetearía la fase de la segunda, que sigue en
        // vuelo. Sin este test la mutación sobrevivía — lo señaló el revisor.
        BaseViewModel.cancellationRecognizer = RecognizerDePrueba()
        let mock = ProductDetailLogicMock()
        let primeraPuerta = Puerta()
        let segundaPuerta = Puerta()
        mock.gate = { llamada in
            await (llamada == 1 ? primeraPuerta : segundaPuerta).esperar()
        }
        mock.errorToThrow = ProductDetailError.cancelled
        let viewModel = ProductDetailViewModel(logic: mock, productID: 7, router: Coordinator(root: .products))

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

// `RecognizerDePrueba` y `Puerta` viven en `PlatformTestSupport`: los usan varios targets de
// test, y `plataforma` → «Dónde vive un helper de test compartido» prohíbe la copia privada.
