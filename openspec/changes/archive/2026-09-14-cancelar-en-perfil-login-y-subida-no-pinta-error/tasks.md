# Tareas

Tres rutas, y en cada una las cuatro cláusulas del requisito «Una cancelación que se lanza no se
le presenta al usuario como error». El patrón ya existe en cinco features: se sigue, no se
inventa. Antes de escribir cualquier función nueva, `/kit-duplicados`.

## Perfil — `performLoad`, así que `setIdle()`

- [x] 1. `ProfileError`: caso `cancelled`, `isRetryable == false`, `screenError` desde
      `ErrorCopy.Cancelled`.
- [x] 2. `ProfileLogic.mapError`: `.cancelled` deja de caer en `default: return .unknown`.
- [x] 3. `ProfileViewModel.load`: captura la cancelación, `setIdle()` solo si su `Task` sigue
      viva, y la relanza.

## Login — `performLoad`, así que `setIdle()`

- [x] 4. `LoginError`: lo mismo que la 1.
- [x] 5. `LoginLogic.mapError`: lo mismo que la 2.
- [x] 6. `LoginViewModel.login`: lo mismo que la 3.

## Subida — `activity(style: .inline)`, así que `stopActivity()`

- [x] 7. `UploadsError`: caso `cancelled` para la RED, junto al `captureCancelled` que ya existe
      para la cámara. Son dos cosas distintas y el acuerdo dice por qué; el nuevo va a
      `ErrorCopy.Cancelled`, el viejo conserva su copy propia.
- [x] 8. `UploadsLogic.mapError`: lo mismo que la 2. Solo la ruta de red: `capturePhoto()` no se
      toca.
- [x] 9. `UploadsViewModel.performUpload`: captura la cancelación y llama a `stopActivity()` —no
      `setIdle()`—, solo si su `Task` sigue viva. `_runActivity:451` se va sin pararla, que es
      justo el fallo.

## La cáscara y los dobles

- [x] 10. `App/AppCancellationRecognizer`: registra los tres casos nuevos; su lista pasa de
      cuatro tipos a siete.
- [x] 11. `ProfileLogicMock`, `LoginLogicMock` y `UploadsLogicMock`: un `gate` como el de
      `CartLogicMock`, que ninguno tiene y sin el cual no se puede escribir la tarea 13.

## Tests

- [x] 12. Por ruta: que el transporte cancelado mapea al caso nuevo, y que la pantalla no queda
      en error ni colgada —`.loading` en Perfil y Login, indicador puesto en la subida—.
- [x] 13. En Perfil y Login: que una operación superada por otra no le quita el indicador a la
      que la superó. Es el test que fija el `if !Task.isCancelled`; se escribe con `Puerta`, que
      ya vive en `PlatformTestSupport`, y se comprueba que la mutación NO sobrevive.

      *Enmienda del 2026-09-14, al implementar. La tarea decía «por ruta», incluyendo la subida,
      y es imposible: `activity(style:)` → `_runActivity` NO cancela a la anterior —no hay
      `inFlightActivity?.cancel()` ahí, al contrario que en `_performLoad`/`_performActivity`—,
      así que en Uploads no existe una subida que supere a otra. Su `if !Task.isCancelled` es
      defensivo, cumple la cláusula 4 del requisito, y su mutación sobrevive. Se deja escrito en
      vez de fingir un test que no prueba nada.*
- [x] 14. `AppTests/CancellationRecognizerTests`: los tres tipos nuevos, más una aserción por
      feature de que un error normal suyo NO se confunde con cancelación.

## Cierre

- [x] 15. Medir la lógica repetida contra HEAD —en un worktree limpio, que es lo que distingue
      «grupo nuevo» de «grupo que ya estaba»— y declarar el resultado en el acuerdo con su
      medición. Hoy son 4 grupos.

      *Medido el 2026-09-14 con `busca-duplicados.py App Packages AppTests AppSnapshotTests`,
      en un worktree limpio de `3cd4ba4` para el baseline y sobre el árbol para el resultado:
      **4 antes, 4 después**, pero no son los mismos cuatro. Se rompió `dd13b693f6`
      (`ProfileLogicMock.loadProfile` ≡ `ProfileServiceMock.me`) al darle el `gate` y el
      contador a `loadProfile`, y apareció `1f074820d8` — el `mapError` de Uploads, que al
      ganar `.cancelled` quedó idéntico a `CatalogError.from`. Neto cero por casualidad, no
      por diseño.*
- [x] 16. `/kit-verifica` en verde.
