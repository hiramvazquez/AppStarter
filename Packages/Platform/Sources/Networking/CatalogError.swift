import AppFoundation
import CoreNetworking
import Domain
import Foundation

/// El error de las features que consumen `ProductsServicing` y traducen sus mismos fallos.
///
/// Vive aquí y no en cada feature porque `ProductsFeature` y `SearchFeature` declaraban el
/// mismo enum con otro nombre: mismos cuatro casos, mismo `isRetryable`, mismo `screenError` y
/// mismo mapeo. Cuando `ErrorCopy` cambió hubo que tocar los dos ficheros.
///
/// Y vive en `Networking` y no en `Domain`, que es donde se intentó primero: `.archlint.yml`
/// declara `Domain: allowedImports: [Foundation]`, así que allí no se puede importar ni
/// `AppFoundation` —de donde viene `ScreenError`— ni `CoreNetworking` —de donde viene
/// `APIError`—. `Networking` ya importa los dos legalmente, ya depende de `Domain` para leer
/// `ErrorCopy`, y todas las features que lo necesitan ya dependen de él. El propio `ErrorCopy`
/// lleva escrito por qué guarda `String` y no `ScreenError`: por esta misma frontera.
///
/// LÍMITE DECLARADO: esto NO es «el error de la app». Las features que no comparten el
/// conjunto de casos conservan el suyo — `FavoritesError` tiene dos y `CartError` cinco. Añadir
/// casos aquí para acomodarlas sería inventar estados que nadie usa.
public enum CatalogError: DomainError, Equatable {
    case offline
    case server
    case cancelled
    case unknown

    /// `.cancelled` NO es reintentable: un botón de «Reintentar» sobre algo que se acaba
    /// de cancelar invita a deshacer esa decisión. Mismo criterio que `DiagnosticsError`.
    public var isRetryable: Bool {
        switch self {
        case .cancelled: false
        case .offline, .server, .unknown: true
        }
    }

    public var screenError: ScreenError {
        switch self {
        case .offline:
            return ScreenError(title: ErrorCopy.Offline.title, message: ErrorCopy.Offline.message)
        case .server:
            return ScreenError(title: ErrorCopy.Server.title, message: ErrorCopy.Server.message)
        // Este arm NO debería renderizarse nunca: `AppCancellationRecognizer` intercepta
        // el caso antes de que `BaseViewModel` llame a `setError`. Existe porque el
        // `switch` es exhaustivo, y devuelve el texto genérico A PROPÓSITO — inventar copy
        // propia aquí sería escribir un mensaje para una pantalla que no debe aparecer, y
        // haría creer al siguiente que este camino es normal. Lo que mantiene el arm
        // inalcanzable es el test del recognizer, no este comentario.
        case .cancelled:
            return ScreenError(title: ErrorCopy.Unknown.title, message: ErrorCopy.Unknown.message)
        case .unknown:
            return ScreenError(title: ErrorCopy.Unknown.title, message: ErrorCopy.Unknown.message)
        }
    }

    /// Traduce un fallo del transporte al caso del dominio.
    ///
    /// Una cancelación mapea a `.cancelled` y no a `.unknown`: eso es lo que permite que
    /// `AppCancellationRecognizer` la reconozca y no pinte una pantalla de error por algo que
    /// el usuario acaba de pedir que pare.
    public static func from(_ error: APIError) -> CatalogError {
        switch error.category {
        case .offline: return .offline
        case .server: return .server
        case .cancelled: return .cancelled
        default: return .unknown
        }
    }
}
