## ADDED Requirements

### Requirement: Una cancelación que se lanza no se le presenta al usuario como error

Una feature cuya `Logic` **lanza** un error de dominio que representa cancelación SHALL
cumplir las cuatro cosas, o no lanzarlo:

1. su `mapError` SHALL traducir `APIError.Category.cancelled` a ese caso, no a `.unknown`;
2. ese caso SHALL tener `isRetryable == false` — ofrecer «Reintentar» sobre algo cancelado
   invita a deshacer la decisión que se acaba de tomar;
3. el caso SHALL estar registrado en el `CancellationRecognizing` de la app, para que
   `BaseViewModel` lo descarte antes de llegar a `setError`;
4. la feature SHALL devolver la fase a un estado del que se pueda salir, y SHALL hacerlo
   solo si su `Task` sigue viva.

La cuarta no es cosmética: `performLoad`/`performActivity` salen de una cancelación
reconocida por un `return` seco que no toca `phase`, así que la fase transitoria puesta
ANTES de arrancar se queda puesta y la pantalla se cuelga en `.loading` para siempre —sin
contenido, sin error, sin reintentar—, que es peor que mostrar el error. Y el reset tiene que
mirar `Task.isCancelled` porque `performLoad` cancela la carga anterior al arrancar la
nueva: sin esa condición, la superada le quita el indicador de progreso a la que la superó.

**El requisito se aplica a la cancelación que llega desde la red, que la pantalla nunca pidió
y que por tanto no debe presentar.** De las diez features con error de dominio propio, cuatro
tienen un caso que representa una cancelación:

- `ProductsFeature` y `SearchFeature` la lanzan traducida de `APIError.Category.cancelled`, y
  por tanto cumplen las cuatro cláusulas.
- `DiagnosticsFeature` no la lanza —su `run` no es `throws`—: guarda el caso como dato en su
  `DiagnosticsResult` y lo pinta en una fila a propósito, así que nunca llega a
  `BaseViewModel`.
- `UploadsFeature` **sí la lanza** (`UploadsError.captureCancelled`), pero no viene de un
  `APIError`: viene de `CameraCaptureError.cancelled`, o sea del usuario cerrando la cámara
  sin disparar. Ahí la cancelación ES el resultado de la pantalla, y se presenta a propósito
  como contenido («Cancelado / No se tomó ninguna foto.»). Queda excluida por decisión: solo
  cumple la cláusula 2 y no debe cumplir las otras tres. Es una exclusión distinta de la de
  Diagnostics —aquella no lanza, esta lanza y presenta a sabiendas—.

Las otras seis no tienen ningún caso de esta clase.

#### Scenario: Una carga cancelada con la pantalla montada

- **WHEN** una carga de una feature que lanza cancelación falla con ella y la `Task` NO está cancelada
- **THEN** el view model no queda en estado de error
- **AND** tampoco queda en `.loading`: la pantalla se puede seguir usando

#### Scenario: Una carga superada por otra

- **WHEN** una segunda carga cancela a la primera y sigue en vuelo
- **THEN** la primera, al desenrollarse, no toca la fase
- **AND** la segunda conserva su indicador de progreso

#### Scenario: Un error de dominio normal

- **WHEN** una carga falla por un error que no es cancelación
- **THEN** el reconocedor no lo intercepta
- **AND** la pantalla muestra su error como siempre

#### Scenario: Una feature que expone la cancelación como dato

- **WHEN** una feature guarda el caso de cancelación en su resultado en vez de lanzarlo
- **THEN** este requisito no le aplica
- **AND** puede presentarlo como parte de su contenido
