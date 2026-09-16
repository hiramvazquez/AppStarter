import AppFoundation
import CoreNetworking
import Domain
import Foundation

/// La traducción de un fallo del transporte al error de dominio, escrita una sola vez.
///
/// Vive aquí y no en cada feature porque `CartError`, `GalleryError` y `ProductDetailError`
/// declaraban el MISMO `mapError` —ocho líneas, tres copias, huella `3450e859ac` del detector— y
/// los dos primeros además el mismo `isRetryable`. Cada copia era una oportunidad de olvidar una
/// categoría: `APIError.Category` tiene trece casos y las features nombran cuatro.
///
/// Y vive en `Networking` por la misma frontera que documenta `CatalogError`: `.archlint.yml`
/// declara `Domain: allowedImports: [Foundation]`, así que allí no se puede importar ni
/// `AppFoundation` —de donde viene `DomainError`— ni `CoreNetworking` —de donde viene `APIError`—.
///
/// **Lo que este protocolo NO comparte, a propósito: el `screenError`.** Cada feature conserva el
/// suyo. `CartError.notFound` dice «Sin carrito / No encontramos el carrito de esta cuenta.» donde
/// Gallery y ProductDetail usan `ErrorCopy.NotFound`, porque en el carrito el texto de producto
/// sería falso: lo que no existe es el carrito, no un producto. Lo fija
/// `CartModelTests.missingCartHasItsOwnCopy`. Lo que se comparte es la lógica, no lo que lee el
/// usuario.
///
/// LÍMITE DECLARADO: esto NO es «el mapeo de la app». Sirve a quien tenga EXACTAMENTE estos cinco
/// casos. `UploadsError` y `CatalogError` no tienen `notFound` y conservan el suyo; añadirles el
/// caso para que encajaran sería inventar un estado que esas pantallas no usan, que es lo mismo
/// que `CatalogError` ya declara sobre sí mismo.
///
/// Hereda de `DomainError` y no lo acompaña: si fueran hermanos, el `isRetryable` por defecto de
/// los dos protocolos sería ambiguo para un conformante. Heredando, éste es el más específico y es
/// el que gana.
public nonisolated protocol TransportMappable: DomainError, Equatable {
    static var offline: Self { get }
    static var notFound: Self { get }
    static var server: Self { get }
    static var cancelled: Self { get }
    static var unknown: Self { get }
}

public nonisolated extension TransportMappable {
    /// Traduce un fallo del transporte al caso del dominio.
    ///
    /// Una cancelación mapea a `.cancelled` y no a `.unknown`: eso es lo que permite que
    /// `AppCancellationRecognizer` la reconozca y no pinte una pantalla de error por algo que el
    /// usuario acaba de pedir que pare.
    ///
    /// Las nueve categorías que no se nombran caen en `.unknown` por el `default`. Es deliberado
    /// y está fijado por un test aquí, no en cada feature: mientras esto se escribía tres veces,
    /// nadie comprobaba ese camino ni una sola vez.
    static func from(_ error: APIError) -> Self {
        switch error.category {
        case .offline: return .offline
        case .notFound: return .notFound
        case .server: return .server
        case .cancelled: return .cancelled
        default: return .unknown
        }
    }

    /// Ni lo que no se encontró ni lo que se canceló se reintentan.
    ///
    /// `.notFound` porque reintentar no va a hacer aparecer lo que no existe, y `.cancelled`
    /// porque ofrecer «Reintentar» sobre algo que el usuario acaba de cancelar invita a deshacer
    /// la decisión que acaba de tomar.
    ///
    /// Se escribe por exclusión y no enumerando: así un caso propio de una feature
    /// —`ProductDetailError.favoriteStorageFailure`— hereda `true` sin que este protocolo tenga
    /// que conocerlo. Lo que convierte esa herencia en contrato es el test de esa feature, no
    /// esta línea.
    var isRetryable: Bool { self != Self.notFound && self != Self.cancelled }
}
