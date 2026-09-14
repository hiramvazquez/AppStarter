import AppFoundation
import Foundation

/// Reconoce la cancelación por el NOMBRE del caso, para los tests de ViewModel de cada feature.
///
/// Vive aquí y no copiado en cada target porque lo exige `plataforma` → «Dónde vive un helper de
/// test compartido»: un helper que necesiten dos o más `*FeatureTests` va en
/// `PlatformTestSupport` y no se duplica. Llegó a estar copiado en cinco targets, con el mismo
/// cuerpo de una línea — que el detector de lógica repetida no ve, y por eso existe el requisito.
///
/// Lo que NO cubre, y por eso no sustituye a nada: el `AppCancellationRecognizer` de verdad, que
/// vive en `App/` y ningún target de feature puede importar (R13). De ese se encarga
/// `AppTests/CancellationRecognizerTests`, que es quien fija qué tipos están registrados.
public struct RecognizerDePrueba: CancellationRecognizing {
    public init() {}

    public func isCancellation(_ error: any Error) -> Bool {
        String(describing: error) == "cancelled"
    }
}
