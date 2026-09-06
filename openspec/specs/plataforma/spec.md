# Plataforma — spec viva

## Kits del proyecto

| kit | versión mínima | qué aporta |
|---|---|---|
| AppFoundation | **1.3.1** | `ScreenContainer`, `BaseViewModel`, navegación, archlint |
| CoreNetworking | **1.2.2** | `APIService`, interceptores, reintentos, pinning |

## Cancelación del trabajo en vuelo al desmontar una pantalla

Una pantalla que lanza trabajo asíncrono **cancela ese trabajo cuando se la elimina de la
jerarquía** de navegación (pop, dismiss, pestaña destruida).

**No lo cancela cuando queda TAPADA** por un push: al volver, su carga sigue siendo válida.

`ScreenContainer(_:cancelsInFlightWorkOnRemoval:)` viene a **`true` por defecto** desde
AppFoundation 1.3.0.

### Excepciones declaradas

| pantalla | valor | por qué |
|---|---|---|
| `UploadsFeature` | `false` | su trabajo es una subida con barra de progreso: perderla porque el usuario navegó fuera es peor que el problema que el default resuelve |
| `LoginFeature` | `true` (default) | **pendiente de decisión del owner**: cancelar un login al salir es probablemente correcto, pero es decisión de producto |

## Errores envueltos

Un `WrappedError` presenta al usuario **solo** el mensaje de la capa que envuelve. El error
interno va al log, nunca a pantalla. (Antes de AppFoundation 1.2.6 se filtraba: era un
fallo de seguridad.)
