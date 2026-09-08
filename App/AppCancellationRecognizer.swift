import AppFoundation
import CartFeature
import Foundation
import ProductsFeature
import SearchFeature

/// Reconoce las cancelaciones que este app expresa con sus propios tipos de dominio.
///
/// `DefaultCancellationRecognizer` solo entiende `CancellationError` y
/// `URLError(.cancelled)`. Nuestras features no lanzan ninguno de los dos: su `Logic`
/// traduce el `APIError` a un error de dominio ANTES de devolverlo (la regla M1 de
/// `AGENTS.md`), así que una cancelación llega aquí como `ProductsError.cancelled`, y el
/// reconocedor por defecto la deja pasar hasta la pantalla.
///
/// Vive en `App/` porque es el único sitio que puede ver dos features a la vez: una
/// `*Feature` no puede importar otra (R13).
///
/// Al añadir una feature que LANZA una cancelación venida de la red, hay que añadirla aquí
/// **y** a `AppTests/CancellationRecognizerTests`. No toda cancelación entra: `UploadsError`
/// tiene `captureCancelled` y se queda fuera a propósito, porque no viene de un `APIError`
/// sino de que el usuario cerró la cámara, y esa pantalla la presenta como su resultado. Y no hay nada que lo impida olvidar: el test de
/// «no queda en estado de error» de esa feature usa su propio doble —no puede importar
/// `App/` (R13)—, así que estará en verde igualmente. La red es la enumeración explícita de
/// ese test, no un mecanismo que se dispare solo.
/// (Una versión anterior de este comentario afirmaba lo contrario. Era falso.)
struct AppCancellationRecognizer: CancellationRecognizing {
    func isCancellation(_ error: any Error) -> Bool {
        switch error {
        case ProductsError.cancelled, SearchError.cancelled, CartError.cancelled: true
        // Se delega en el de por defecto en vez de reimplementar sus dos casos: si
        // AppFoundation amplía lo que reconoce, esto lo hereda. Se construye aquí, sin
        // propiedad almacenada, porque el valor por defecto de una propiedad se evalúa en
        // un contexto distinto y el compilador lo rechaza. Es un struct sin estado.
        default: DefaultCancellationRecognizer().isCancellation(error)
        }
    }
}
