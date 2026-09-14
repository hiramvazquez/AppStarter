import AppFoundation
import AppFoundationTestSupport
import Domain
import Foundation
import Observation
import PlatformTestSupport
import Testing

@testable import GalleryFeatureCore
@testable import GalleryFeatureUI

// `RecognizerDePrueba` y `Puerta` viven en `PlatformTestSupport`: los usan varios targets de
// test, y `plataforma` → «Dónde vive un helper de test compartido» prohíbe la copia privada.

/// `GalleryViewModel` tested only against `GalleryLogicMock` — no `GalleryService` real,
/// no network involved.
@Suite("GalleryViewModel")
@MainActor
struct GalleryViewModelTests {
    private static let images = [
        URL(string: "https://cdn.dummyjson.com/a.png")!,
        URL(string: "https://cdn.dummyjson.com/b.png")!,
        URL(string: "https://cdn.dummyjson.com/c.png")!
    ]

    @Test("handle(.load) calls logic.load(productID:) and reaches .content when non-empty")
    func loadReachesContent() async {
        let mock = GalleryLogicMock()
        mock.stateToReturn = GalleryState(title: "Robot Bear", images: Self.images)
        let viewModel = GalleryViewModel(logic: mock, productID: 3, router: Coordinator(root: .products))

        viewModel.handle(.load)
        await viewModel.inFlightLoad?.value

        #expect(mock.loadCallCount == 1)
        #expect(viewModel.phase == .content)
        #expect(viewModel.title == "Robot Bear")
        #expect(viewModel.images == Self.images)
    }

    @Test("handle(.load) reaches .empty when the product has no images")
    func loadReachesEmptyWhenNoImages() async {
        let mock = GalleryLogicMock()
        mock.stateToReturn = GalleryState(title: "Robot Bear", images: [])
        let viewModel = GalleryViewModel(logic: mock, productID: 3, router: Coordinator(root: .products))

        viewModel.handle(.load)
        await viewModel.inFlightLoad?.value

        #expect(viewModel.phase == .empty)
    }

    @Test("A failing logic.load lands on .error")
    func loadFailureSurfacesError() async {
        let mock = GalleryLogicMock()
        mock.errorToThrow = GalleryError.unknown
        let viewModel = GalleryViewModel(logic: mock, productID: 3, router: Coordinator(root: .products))

        viewModel.handle(.load)
        await viewModel.inFlightLoad?.value

        #expect(viewModel.hasError)
    }

    @Test("handle(.select) updates selectedIndex, ignoring an out-of-bounds index")
    func selectUpdatesIndex() async {
        let mock = GalleryLogicMock()
        mock.stateToReturn = GalleryState(title: "Robot Bear", images: Self.images)
        let viewModel = GalleryViewModel(logic: mock, productID: 3, router: Coordinator(root: .products))
        viewModel.handle(.load)
        await viewModel.inFlightLoad?.value

        viewModel.handle(.select(index: 2))
        #expect(viewModel.selectedIndex == 2)

        viewModel.handle(.select(index: 99))
        #expect(viewModel.selectedIndex == 2)
    }

    @Test("handle(.scrolled) throttles a single prefetch of the next image")
    func scrolledThrottlesPrefetchOfNextImage() async {
        let mock = GalleryLogicMock()
        mock.stateToReturn = GalleryState(title: "Robot Bear", images: Self.images)
        let viewModel = GalleryViewModel(logic: mock, productID: 3, router: Coordinator(root: .products))
        viewModel.handle(.load)
        await viewModel.inFlightLoad?.value

        viewModel.handle(.scrolled(toIndex: 0))
        viewModel.handle(.scrolled(toIndex: 1))
        await viewModel.inFlightPrefetch?.value

        #expect(viewModel.selectedIndex == 1)
        #expect(mock.prefetchedURLs.contains(Self.images[1]))
    }

    @Test("handle(.scrolled) at the last image does not prefetch past the end")
    func scrolledAtLastImageDoesNotPrefetch() async {
        let mock = GalleryLogicMock()
        mock.stateToReturn = GalleryState(title: "Robot Bear", images: Self.images)
        let viewModel = GalleryViewModel(logic: mock, productID: 3, router: Coordinator(root: .products))
        viewModel.handle(.load)
        await viewModel.inFlightLoad?.value

        viewModel.handle(.scrolled(toIndex: Self.images.count - 1))

        // No prefetch Task is even spawned past the last index (`scrolled(toIndex:)`
        // returns before reaching `inFlightPrefetch = Task { ... }`) — nothing to await.
        #expect(viewModel.inFlightPrefetch == nil)
        #expect(mock.prefetchedURLs.isEmpty)
    }

    @Test("una carga cancelada deja la pantalla en un estado del que se puede salir")
    func cargaCancelada() async {
        BaseViewModel.cancellationRecognizer = RecognizerDePrueba()
        let mock = GalleryLogicMock()
        mock.errorToThrow = GalleryError.cancelled
        let viewModel = GalleryViewModel(logic: mock, productID: 3, router: Coordinator(root: .products))

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
        let mock = GalleryLogicMock()
        let primeraPuerta = Puerta()
        let segundaPuerta = Puerta()
        mock.gate = { llamada in
            await (llamada == 1 ? primeraPuerta : segundaPuerta).esperar()
        }
        mock.errorToThrow = GalleryError.cancelled
        let viewModel = GalleryViewModel(logic: mock, productID: 3, router: Coordinator(root: .products))

        viewModel.handle(.load)
        let primera = viewModel.inFlightLoad

        viewModel.handle(.load)          // cancela la primera y arranca la segunda
        await primeraPuerta.abrir()
        await primera?.value

        #expect(viewModel.isLoading, "la segunda carga sigue en vuelo")

        await segundaPuerta.abrir()      // se suelta para no dejar la Task colgada
        await viewModel.inFlightLoad?.value
    }

    @Test("handle(.scrolled) twice within the throttle window prefetches once; past the window, prefetches again")
    func scrolledRespectsThrottleWindowWithManualClock() async {
        let clock = ManualClock()
        let mock = GalleryLogicMock()
        mock.stateToReturn = GalleryState(title: "Robot Bear", images: Self.images)
        let viewModel = GalleryViewModel(logic: mock, productID: 3, router: Coordinator(root: .products), clock: clock)
        viewModel.handle(.load)
        await viewModel.inFlightLoad?.value

        // First scroll: `Throttler` is outside any cooldown (`lastExecutionTime == nil`),
        // so it executes immediately — no clock advance needed.
        viewModel.handle(.scrolled(toIndex: 0))
        await viewModel.inFlightPrefetch?.value
        #expect(mock.prefetchedURLs == [Self.images[1]])

        // Second scroll, still inside the 400ms window: throttled — no new prefetch.
        viewModel.handle(.scrolled(toIndex: 1))
        await viewModel.inFlightPrefetch?.value
        #expect(mock.prefetchedURLs == [Self.images[1]])

        // Advance PAST the window, then scroll again: the throttle allows it through.
        clock.advance(by: .milliseconds(500))
        viewModel.handle(.scrolled(toIndex: 0))
        await viewModel.inFlightPrefetch?.value
        #expect(mock.prefetchedURLs == [Self.images[1], Self.images[1]])
    }

    @Test("handle(.share) sets shareURL to the currently selected image; .dismissShare clears it")
    func shareSetsCurrentImageURL() async {
        let mock = GalleryLogicMock()
        mock.stateToReturn = GalleryState(title: "Robot Bear", images: Self.images)
        let viewModel = GalleryViewModel(logic: mock, productID: 3, router: Coordinator(root: .products))
        viewModel.handle(.load)
        await viewModel.inFlightLoad?.value
        viewModel.handle(.select(index: 1))

        viewModel.handle(.share)
        #expect(viewModel.shareURL == Self.images[1])

        viewModel.handle(.dismissShare)
        #expect(viewModel.shareURL == nil)
    }

    @Test("handle(.close) pops the router")
    func closePopsRouter() {
        let mock = GalleryLogicMock()
        let router = Coordinator<AppRoute>(root: .products)
        router.push(.gallery(productID: 3))
        let viewModel = GalleryViewModel(logic: mock, productID: 3, router: router)

        viewModel.handle(.close)

        #expect(router.mainStack.path.isEmpty)
    }

    @Test("Changing images notifies Observation — GalleryViewModel's own @Observable (docs/INFORME-MULTI.md §11)")
    func changingImagesNotifiesObservation() async {
        let mock = GalleryLogicMock()
        mock.stateToReturn = GalleryState(title: "Robot Bear", images: Self.images)
        let viewModel = GalleryViewModel(logic: mock, productID: 3, router: Coordinator(root: .products))
        let flag = ObservationFlag()

        withObservationTracking {
            _ = viewModel.images
        } onChange: {
            flag.fired = true
        }
        viewModel.handle(.load)
        await viewModel.inFlightLoad?.value

        #expect(flag.fired)
    }
}
