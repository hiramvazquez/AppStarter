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
        let r = AppCancellationRecognizer()
        #expect(r.isCancellation(CatalogError.cancelled))
        #expect(r.isCancellation(CartError.cancelled))
        #expect(r.isCancellation(GalleryError.cancelled))
        #expect(r.isCancellation(ProductDetailError.cancelled))
        #expect(r.isCancellation(ProfileError.cancelled))
        #expect(r.isCancellation(LoginError.cancelled))
        #expect(r.isCancellation(UploadsError.cancelled))
    }

    /// La distinción que más fácil se rompe al tocar esto: `UploadsError` tiene DOS casos de
    /// cancelación y solo uno se intercepta. `captureCancelled` es el usuario cerrando la
    /// cámara, y esa pantalla lo presenta como su resultado —«Cancelado / No se tomó ninguna
    /// foto.»—, así que reconocerlo aquí lo haría desaparecer de la pantalla sin dejar rastro.
    @Test("la cancelación de cámara NO se intercepta — esa pantalla sí la presenta")
    func noSeComeLaCancelacionDeCamara() {
        let r = AppCancellationRecognizer()
        #expect(r.isCancellation(UploadsError.captureCancelled) == false)
    }

    @Test("no reconoce un error de dominio normal — la pantalla lo sigue mostrando")
    func noSeComeLosErroresDeVerdad() {
        let r = AppCancellationRecognizer()
        #expect(r.isCancellation(CatalogError.server) == false)
        #expect(r.isCancellation(CatalogError.offline) == false)
        #expect(r.isCancellation(CatalogError.unknown) == false)
        #expect(r.isCancellation(GalleryError.notFound) == false)
        #expect(r.isCancellation(ProductDetailError.favoriteStorageFailure) == false)
        #expect(r.isCancellation(CartError.server) == false)
        #expect(r.isCancellation(ProfileError.unauthorized) == false)
        #expect(r.isCancellation(LoginError.invalidCredentials) == false)
        #expect(r.isCancellation(UploadsError.captureFailed) == false)
    }

    @Test("sigue reconociendo lo que reconocía el de por defecto")
    func delegaEnElPorDefecto() {
        let r = AppCancellationRecognizer()
        #expect(r.isCancellation(CancellationError()))
        #expect(r.isCancellation(URLError(.cancelled)))
        #expect(r.isCancellation(URLError(.notConnectedToInternet)) == false)
    }
}
