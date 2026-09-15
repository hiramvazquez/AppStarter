import AppFoundation
import CartFeature
import Domain
import Foundation
import GalleryFeatureCore
import LoginFeature
import Networking
import ProductDetailFeature
import ProductsFeature
import ProfileFeature
import SearchFeature
import Testing
import UploadsFeature

@testable import AppStarter

/// El contrato que de verdad importa del reconocedor: que una cancelación **no acabe en
/// pantalla**. Los tests de la traducción y de `isRetryable` viven en cada feature y son
/// necesarios, pero los tres pueden estar verdes con el usuario viendo un error igualmente
/// — que es exactamente lo que pasaba antes de este cambio.
///
/// Vive en `AppTests` porque el reconocedor está en `App/`: es el único sitio que ve dos
/// features a la vez (R13).
@Suite("AppCancellationRecognizer")
@MainActor
struct CancellationRecognizerTests {
    @Test("reconoce los .cancelled de las features")
    func reconoceLosDeDominio() {
        let recognizer = AppCancellationRecognizer()
        #expect(recognizer.isCancellation(CatalogError.cancelled))
        #expect(recognizer.isCancellation(CartError.cancelled))
        #expect(recognizer.isCancellation(GalleryError.cancelled))
        #expect(recognizer.isCancellation(ProductDetailError.cancelled))
        #expect(recognizer.isCancellation(ProfileError.cancelled))
        #expect(recognizer.isCancellation(LoginError.cancelled))
        #expect(recognizer.isCancellation(UploadsError.cancelled))
    }

    /// La distinción que más fácil se rompe al tocar esto: `UploadsError` tiene DOS casos de
    /// cancelación y solo uno se intercepta. `captureCancelled` es el usuario cerrando la
    /// cámara, y esa pantalla lo presenta como su resultado —«Cancelado / No se tomó ninguna
    /// foto.»—, así que reconocerlo aquí lo haría desaparecer de la pantalla sin dejar rastro.
    @Test("la cancelación de cámara NO se intercepta — esa pantalla sí la presenta")
    func noSeComeLaCancelacionDeCamara() {
        let recognizer = AppCancellationRecognizer()
        #expect(recognizer.isCancellation(UploadsError.captureCancelled) == false)
    }

    @Test("no reconoce un error de dominio normal — la pantalla lo sigue mostrando")
    func noSeComeLosErroresDeVerdad() {
        let recognizer = AppCancellationRecognizer()
        #expect(recognizer.isCancellation(CatalogError.server) == false)
        #expect(recognizer.isCancellation(CatalogError.offline) == false)
        #expect(recognizer.isCancellation(CatalogError.unknown) == false)
        #expect(recognizer.isCancellation(GalleryError.notFound) == false)
        #expect(recognizer.isCancellation(ProductDetailError.favoriteStorageFailure) == false)
        #expect(recognizer.isCancellation(CartError.server) == false)
        #expect(recognizer.isCancellation(ProfileError.unauthorized) == false)
        #expect(recognizer.isCancellation(LoginError.invalidCredentials) == false)
        #expect(recognizer.isCancellation(UploadsError.captureFailed) == false)
    }

    @Test("sigue reconociendo lo que reconocía el de por defecto")
    func delegaEnElPorDefecto() {
        let recognizer = AppCancellationRecognizer()
        #expect(recognizer.isCancellation(CancellationError()))
        #expect(recognizer.isCancellation(URLError(.cancelled)))
        #expect(recognizer.isCancellation(URLError(.notConnectedToInternet)) == false)
    }
}
