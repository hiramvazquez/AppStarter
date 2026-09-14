import AppFoundation
import CoreNetworking
import CoreNetworkingTestSupport
import Foundation
import Testing

@testable import Networking

/// Un conformante mínimo, con los cinco casos y nada más.
private enum ErrorDePrueba: TransportMappable {
    case offline
    case notFound
    case server
    case cancelled
    case unknown

    var screenError: ScreenError { ScreenError(title: "t", message: "m") }
}

/// Un conformante con un caso PROPIO, que el protocolo no conoce. Reproduce la forma de
/// `ProductDetailError.favoriteStorageFailure`.
private enum ErrorConCasoPropio: TransportMappable {
    case offline
    case notFound
    case server
    case cancelled
    case unknown
    case propio

    var screenError: ScreenError { ScreenError(title: "t", message: "m") }
}

/// La traducción del transporte, probada UNA vez en el nivel compartido.
///
/// El caso que estos tests existen para cubrir no lo cubría nadie: mientras el `mapError` estaba
/// escrito en tres features, las nueve categorías de `APIError.Category` que ninguna enumera no
/// se comprobaban ni una sola vez. Cada copia podía haberlas mandado a otro sitio.
@Suite("TransportMappable")
struct TransportMappableTests {
    @Test("las cuatro categorías nombradas mapean a su caso")
    func categoriasNombradas() {
        #expect(ErrorDePrueba.from(.stub(code: .transport, underlying: URLError(.notConnectedToInternet))) == .offline)
        #expect(ErrorDePrueba.from(.stub(code: .httpStatus, statusCode: 404)) == .notFound)
        #expect(ErrorDePrueba.from(.stub(code: .httpStatus, statusCode: 503)) == .server)
        #expect(ErrorDePrueba.from(.stub(code: .cancelled, underlying: URLError(.cancelled))) == .cancelled)
    }

    @Test("una categoría que nadie enumera cae en .unknown, no en otro caso")
    func categoriaNoEnumerada() {
        // `APIError.Category` tiene trece casos y el protocolo nombra cuatro. Este test es la
        // cláusula 2 del requisito: el resto cae en `.unknown` a propósito, no por descuido.
        #expect(ErrorDePrueba.from(.stub(code: .decoding)) == .unknown)
        #expect(ErrorDePrueba.from(.stub(code: .httpStatus, statusCode: 401)) == .unknown)
        #expect(ErrorDePrueba.from(.stub(code: .httpStatus, statusCode: 429)) == .unknown)

        // `.untrustedServer` —un pin TLS rechazado— cae aquí también, y por tanto HEREDA
        // reintentable: se le ofrece «Reintentar» a algo que no va a funcionar nunca.
        // `DiagnosticsError` lo trata como caso propio y NO reintentable
        // (`DiagnosticsModels.swift:111`), así que las dos convivencias no dicen lo mismo. Lo
        // señaló el revisor. Este assert NO bendice ese comportamiento: fija cuál es hoy, para que
        // no cambie sin que nadie se entere. Cambiarlo es otra decisión, con su propia medición.
        #expect(ErrorDePrueba.from(.stub(code: .untrustedServer)) == .unknown)
        #expect(ErrorDePrueba.unknown.isRetryable, "hoy un pin rechazado acaba siendo reintentable")
    }

    @Test("ni lo que no se encontró ni lo que se canceló se reintentan; lo demás sí")
    func reintentabilidad() {
        #expect(ErrorDePrueba.notFound.isRetryable == false)
        #expect(ErrorDePrueba.cancelled.isRetryable == false)
        #expect(ErrorDePrueba.offline.isRetryable)
        #expect(ErrorDePrueba.server.isRetryable)
        #expect(ErrorDePrueba.unknown.isRetryable)
    }

    @Test("un caso propio de la feature hereda reintentable sin que el protocolo lo conozca")
    func casoPropioHeredaReintentable() {
        // Es lo que permite que `ProductDetailError` conforme esto sin sobrescribir nada, y la
        // razón por la que `isRetryable` se escribe por exclusión y no enumerando casos.
        #expect(ErrorConCasoPropio.propio.isRetryable)
        #expect(ErrorConCasoPropio.notFound.isRetryable == false)
    }
}
