import Foundation

/// Textos de error que ve el usuario y que muestran DOS O MÁS features.
///
/// Viven aquí y no en cada feature porque son literales de cara al usuario: quien retoque
/// «Comprueba tu red e inténtalo de nuevo.» en una pantalla no tiene forma de saber que hay
/// otra diciendo lo mismo, y las dos divergen sin que nadie se entere. `ProductsError` y
/// `SearchError` los tenían escritos por duplicado, palabra por palabra.
///
/// Son `String` a propósito, no `ScreenError`: ese tipo es de `AppFoundation` y pertenece a
/// la capa de presentación. Guardarlo aquí obligaría a `Domain` —que hoy no depende de
/// nada— a conocer el kit de UI, y esa dependencia no la paga un puñado de textos.
///
/// Un texto que solo usa una feature se queda en ella. Traer aquí algo con un único
/// consumidor convierte una decisión local en superficie compartida para nadie.
///
/// `nonisolated` NO es decorativo: `Package.swift` de Platform declara
/// `.defaultIsolation(MainActor.self)`, así que sin esto las constantes se infieren
/// aisladas al main actor y `XxxError.screenError` —que es `nonisolated`, porque un
/// `DomainError` se construye desde la capa Logic— no puede leerlas. El compilador lo
/// rechaza; no es un aviso.
public nonisolated enum ErrorCopy {
    public enum Offline {
        public static let title = "Sin conexión"
        public static let message = "Comprueba tu red e inténtalo de nuevo."
    }

    public enum Server {
        public static let title = "Error del servidor"
        public static let message = "Inténtalo de nuevo más tarde."
    }

    public enum Unknown {
        public static let title = "Algo salió mal"
        public static let message = "Inténtalo de nuevo."
    }

    /// Ojo con el título: Diagnostics tiene otro «No encontrado», con el mensaje «El recurso
    /// no existe (404).». Es OTRO par y se queda donde está — lo que se comparte es el par
    /// completo, no el título suelto.
    public enum NotFound {
        public static let title = "No encontrado"
        public static let message = "Este producto ya no está disponible."
    }
}
