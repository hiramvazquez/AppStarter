import AppFoundation
import Foundation
import PlatformTestSupport
import Testing

@testable import UploadsFeature

/// `UploadsViewModel` tested only against `UploadsLogicMock` — no `UploadsService`/
/// `CameraKit`/network involved.
@Suite("UploadsViewModel")
@MainActor
struct UploadsViewModelTests {
    @Test("handle(.appear) reaches .content")
    func appearReachesContent() {
        let viewModel = UploadsViewModel(logic: UploadsLogicMock())

        viewModel.handle(.appear)

        #expect(viewModel.phase == .content)
    }

    @Test("handle(.capturePhoto) stores the captured photo data")
    func capturePhotoStoresData() async {
        let mock = UploadsLogicMock()
        mock.photoDataToReturn = Data([0x01, 0x02, 0x03])
        let viewModel = UploadsViewModel(logic: mock)

        viewModel.handle(.capturePhoto)
        await viewModel.inFlightActivity?.value

        #expect(await mock.captureCalls.count == 1)
        #expect(viewModel.capturedPhotoData == Data([0x01, 0x02, 0x03]))
    }

    @Test("A failing capturePhoto() shows a banner and leaves capturedPhotoData nil")
    func captureFailureShowsBanner() async {
        let mock = UploadsLogicMock()
        mock.captureErrorToThrow = UploadsError.captureFailed
        let viewModel = UploadsViewModel(logic: mock)

        viewModel.handle(.capturePhoto)
        await viewModel.inFlightActivity?.value

        #expect(viewModel.capturedPhotoData == nil)
        #expect(viewModel.banner != nil)
    }

    @Test("handle(.upload) is a no-op without a captured photo")
    func uploadWithoutPhotoIsNoOp() async {
        let mock = UploadsLogicMock()
        let viewModel = UploadsViewModel(logic: mock)

        viewModel.handle(.upload)
        try? await Task.sleep(for: .milliseconds(20))

        #expect(await mock.uploadCalls.isEmpty)
    }

    /// El fallo que persigue: `activity(style:)` → `_runActivity` se va de una cancelación
    /// reconocida con un `return` seco que NO llama a `stopActivity()`, así que la barra de
    /// progreso se queda puesta para siempre. Por eso el ViewModel para la actividad a mano.
    ///
    /// No hay gemelo de «subida superada» como en las demás features, y no es un olvido:
    /// `activity(style:)` no cancela a la anterior —no hay `inFlightActivity?.cancel()` en
    /// `_runActivity`—, así que en esta pantalla no existe una subida que supere a otra. El
    /// `if !Task.isCancelled` de ahí es defensivo y su mutación sobrevive; queda declarado en
    /// el acuerdo.
    @Test("una subida cancelada no deja la actividad puesta para siempre")
    func subidaCancelada() async {
        BaseViewModel.cancellationRecognizer = RecognizerDePrueba()
        let mock = UploadsLogicMock()
        let puerta = Puerta()
        mock.gate = { _ in await puerta.esperar() }
        mock.uploadErrorToThrow = UploadsError.cancelled
        let viewModel = UploadsViewModel(logic: mock)

        viewModel.handle(.capturePhoto)
        await viewModel.inFlightActivity?.value

        viewModel.handle(.upload)
        // Se espera a que la subida esté EN VUELO —parada en la puerta— antes de medir nada:
        // sin esto, `isPerformingActivity == false` sería cierto por no haber empezado aún.
        //
        // Y la espera lleva su aserción DETRÁS, que es lo que la convierte en una prueba:
        // `waitUntil` vuelve en silencio al agotar su plazo. Sin esta línea, el día que
        // `handle(.upload)` dejara de arrancar la subida —un `guard` nuevo, o `capturedPhotoData`
        // nulo— las tres aserciones del final serían ciertas POR VACÍO y este test seguiría
        // verde dejando sin cubrir el `stopActivity()`, que es lo único que impide que la barra
        // se quede puesta para siempre.
        await waitUntil { viewModel.isPerformingActivity }
        #expect(viewModel.isPerformingActivity, "la subida sigue en vuelo")

        await puerta.abrir()
        await waitUntil { viewModel.isPerformingActivity == false }

        #expect(viewModel.isPerformingActivity == false)
        #expect(viewModel.hasError == false)
        #expect(viewModel.uploadedProduct == nil)
    }

    @Test("handle(.upload) reports progress, stores the result, and shows a success banner")
    func uploadReportsProgressAndSucceeds() async {
        let mock = UploadsLogicMock()
        mock.photoDataToReturn = Data([0x01])
        mock.progressToReport = [0.3, 0.6, 1.0]
        mock.uploadResultToReturn = UploadedProduct(id: 7, title: "Producto de prueba")
        let viewModel = UploadsViewModel(logic: mock)

        viewModel.handle(.capturePhoto)
        await viewModel.inFlightActivity?.value
        viewModel.handle(.upload)
        await waitUntil { viewModel.uploadedProduct != nil }

        #expect(await mock.uploadCalls.calls == ["Producto de prueba"])
        #expect(viewModel.progress == 1.0)
        #expect(viewModel.uploadedProduct == UploadedProduct(id: 7, title: "Producto de prueba"))
        #expect(viewModel.banner?.style == .success)
    }
}
