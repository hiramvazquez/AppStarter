import AppFoundation
import Domain
import Foundation
import ProductsFeature
import SearchFeature
import Testing

@testable import AppStarter

/// El contrato que de verdad importa del reconocedor: que una cancelación **no acabe en
/// pantalla**. Los tests de `mapError` y de `isRetryable` viven en cada feature y son
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
        #expect(r.isCancellation(ProductsError.cancelled))
        #expect(r.isCancellation(SearchError.cancelled))
    }

    @Test("no reconoce un error de dominio normal — la pantalla lo sigue mostrando")
    func noSeComeLosErroresDeVerdad() {
        let r = AppCancellationRecognizer()
        #expect(r.isCancellation(ProductsError.server) == false)
        #expect(r.isCancellation(ProductsError.offline) == false)
        #expect(r.isCancellation(SearchError.unknown) == false)
    }

    @Test("sigue reconociendo lo que reconocía el de por defecto")
    func delegaEnElPorDefecto() {
        let r = AppCancellationRecognizer()
        #expect(r.isCancellation(CancellationError()))
        #expect(r.isCancellation(URLError(.cancelled)))
        #expect(r.isCancellation(URLError(.notConnectedToInternet)) == false)
    }
}
