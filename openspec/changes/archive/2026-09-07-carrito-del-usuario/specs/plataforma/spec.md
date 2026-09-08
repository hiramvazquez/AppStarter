## MODIFIED Requirements

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
y que por tanto no debe presentar.** Y se aplica por lo que el error SIGNIFICA, no por cómo
se llame el caso: `UploadsError.captureCancelled` no se llama `cancelled` y entra igual en el
razonamiento.

Quedan fuera dos clases de cancelación, cada una por su motivo:

- **La que no se lanza.** Una feature cuya operación no es `throws` y guarda la cancelación
  como dato para pintarla —`DiagnosticsFeature` y su `DiagnosticsResult`— nunca llega a
  `BaseViewModel`, así que no le aplica.
- **La que no viene de la red y la pantalla presenta a sabiendas.**
  `UploadsError.captureCancelled` nace de `CameraCaptureError.cancelled` —el usuario cerrando
  la cámara sin disparar—, y ahí la cancelación ES el resultado de la pantalla
  («Cancelado / No se tomó ninguna foto.»). Cumple la cláusula 2 y NO debe cumplir las otras
  tres.

**Aquí no va un censo de las features que cumplen.** La versión anterior de este requisito
enumeraba «de las diez features… cuatro tienen un caso», y el número caducó con el primer
cambio que añadió una: al llegar `CartFeature` eran once y cinco. Un recuento sobre código
que el requisito no toca envejece solo y nadie vuelve a contarlo, así que lo que manda es el
criterio de arriba. Quien necesite el recuento de hoy, que lo mida:

```bash
grep -rln "enum [A-Za-z]*Error: DomainError" Packages/Features/Sources   # features con error propio
grep -rn  "case .*[Cc]ancel" Packages/Features/Sources                   # candidatas, a filtrar por SIGNIFICADO
```

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

#### Scenario: Una feature nueva que lanza cancelación de red

- **WHEN** se añade una feature cuya `Logic` traduce `APIError.Category.cancelled` a un caso propio
- **THEN** ese caso queda registrado en el `CancellationRecognizing` de la app
- **AND** hay un test que se pone rojo si se quita del registro
