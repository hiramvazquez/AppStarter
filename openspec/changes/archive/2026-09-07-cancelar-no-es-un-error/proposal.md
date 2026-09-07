# Cancelar una carga no es un error

> Documento **reescrito entero**, no parcheado. Traía cuatro remiendos superpuestos («tras la
> ronda 1», «tras la ronda 3», «tras la tercera vuelta») y dos párrafos que se contradecían
> entre sí. El juez de aceptación lo dictaminó así y tenía razón: un acuerdo que ha
> sobrevivido a tres tandas de parches ya no es coherente consigo mismo. El historial de lo
> que se aprendió está al final, en una sección, en vez de incrustado en cada frase.

## Why

Cuando una carga se cancela **a nivel de `URLSession` con la pantalla montada** —la `Task`
sigue viva—, `CoreNetworking` devuelve `APIError(category: .cancelled)`. Los `mapError` de
las features lo dejaban caer en su `default` y lo convertían en `.unknown`, así que la app
enseñaba «Algo salió mal. Inténtalo de nuevo.» por una operación cancelada.

El otro camino —salir de la pantalla mientras carga— ya era silencioso: `ScreenContainer`
llama a `cancelInFlightWork()` y el `guard !Task.isCancelled` de `BaseViewModel` corta antes
de presentar nada. Solo el primero llega al usuario.

`AppFoundation` tiene el mecanismo y el repo no lo usaba: `CancellationRecognizing`, cuyo doc
comment describe este encargo literalmente («extend recognition to your app's error types,
e.g. an `APIError.cancelled` case») y hasta nombra el tipo que faltaba.

## What Changes

- `ProductsError` y `SearchError` ganan `cancelled`; sus `mapError` lo mapean.
- `isRetryable` deja de ser `{ true }` constante: `.cancelled` es `false`.
- Nace `App/AppCancellationRecognizer.swift`, que reconoce esos dos casos y delega el resto
  en `DefaultCancellationRecognizer`. Vive en `App/` porque es el único sitio que ve las dos
  features (R13). Se registra en el composition root.
- Los **cuatro** sitios que resetean la fase al cancelar —`ProductsViewModel.load`,
  `.refresh`, `.loadMore` y `SearchViewModel.search`— lo hacen **solo si la `Task` sigue
  viva**: sin eso, una carga superada por otra le quita el indicador a la que la superó.
- **Sin copy nueva.** Si la cancelación no se presenta, no hay texto que escribir.

## Fuera de alcance

- Las seis features sin ningún caso de cancelación. Se adaptan cuando toque, con el
  reconocedor ya puesto.
- `DiagnosticsFeature`, que expone `cancelled` pero **no lo lanza** —su `run` no es
  `throws`—: lo guarda como dato y lo pinta en una fila a propósito.
- `UploadsFeature`, que **sí lanza** `UploadsError.captureCancelled`, pero cuya cancelación no
  viene de un `APIError` sino de `CameraCaptureError.cancelled` —el usuario cerrando la cámara
  sin disparar— y se presenta a propósito como contenido («Cancelado / No se tomó ninguna
  foto.»). Excluida por decisión, no por descuido, y por un motivo distinto al de Diagnostics.
- La duplicación de `isRetryable` entre las dos features (huella `0e7e1ad65c`, 5 líneas × 2),
  que **este cambio introduce**: era un `{ true }` de una línea y pasa a ser un `switch`
  idéntico en ambas. Misma clase que `mapError` y `screenError`, ya duplicados por lo mismo:
  dos enums iguales que R13 impide compartir.

## Límite conocido

**La línea que registra el reconocedor no la cubre ningún test.** Borrar
`BaseViewModel.cancellationRecognizer = AppCancellationRecognizer()` de
`AppStarterApp.swift:18` deja AppTests y los snapshots en verde, y el usuario vuelve a ver el
error — comprobado por mutación por los dos revisores.

No se cierra aquí: la línea hermana (`errorPresenter`) lleva igual desde antes, así que
arreglarlo es un cambio sobre el composition root entero. Queda escrito para que sea una
decisión y no un olvido.

## Decisión de diseño de los tests

Las suites de cancelación instalan el reconocedor de prueba **sin restaurarlo**, y reconocen
por nombre de caso en vez de por tipo. `BaseViewModel.cancellationRecognizer` es un
`static var` de todo el proceso y las suites corren en paralelo: atarlo a un tipo hace fallar
a la suite gemela, y restaurarlo en un `defer` es peor, porque la que acaba antes lo devuelve
mientras la otra sigue en vuelo. Las dos cosas dieron fallos intermitentes reales.

La vía limpia existe y no se toma aquí: `LogicViewModel.init` **ya reenvía**
`cancellationRecognizer` a `BaseViewModel.init` —lo que AppFoundation documenta como la forma
correcta (DC-AF-3)—, así que bastaría con exponer ese parámetro en los dos `init`. Cambia dos
inicializadores públicos, así que va en su propio cambio.

## Criterios de aceptación

- [ ] `APIError(category: .cancelled)` se mapea a `.cancelled` en las dos features, fijado
      por un test que pasa por `mapError`.
- [ ] `.cancelled.isRetryable == false` en ambas, fijado por test.
- [ ] `AppCancellationRecognizer` devuelve `true` para esos dos casos, `false` para un error
      de dominio normal, y sigue delegando en el de por defecto. Fijado por test.
- [ ] Un view model cuya carga falla con `.cancelled` **no queda en estado de error ni
      colgado en `.loading`**.
- [ ] Los **cuatro** sitios de reset tienen test que muere al quitar el `if !Task.isCancelled`.
- [ ] Ningún test nuevo pasa con el código que dice cubrir revertido. Verificado por
      mutación, uno a uno.
- [ ] `/kit-verifica` en verde.

## Historial, porque el proceso fue el experimento

Este cambio nació como **prueba controlada del kit**: sobre un bug real se plantaron dos
defectos a propósito —darle copy propia a la cancelación en vez de impedir que se presente,
y un test que pasaba con cualquier código— para medir si los sub-agentes cazan lo que no se
les señala.

Los cazaron los dos, por separado, y además encontraron un tercer defecto que nadie plantó
(el botón de «Reintentar» sobre una cancelación) y corrigieron la premisa del planteamiento.
Los cinco gates mecánicos —build, tests de los dos paquetes, app, snapshots y duplicados—
estaban en verde con los defectos dentro.

Costó tres rondas de revisión y seis de aceptación. Las de revisión encontraron **bugs**: el
spinner eterno, un cuarto sitio sin arreglar, el solapamiento entre cargas. Las de aceptación,
desde la segunda, no encontraron ni un fallo de código: encontraron **afirmaciones mías mal
contadas**. Un criterio que decía tener test en cuatro sitios cuando moría uno. Una
declaración de «esto es inalcanzable» que era falsa y estaba escrita en un comentario
permanente. «Las otras siete features» cuando eran ocho. Y la última, la más fina: el censo de
este documento era **léxico** —«un caso llamado `cancelled`»— mientras el requisito era
**semántico**, y en ese hueco cabía `UploadsError.captureCancelled`, que sí se lanza y que no
debe cumplir la norma.

La lección que merece sobrevivir: **una afirmación sobre el código es una hipótesis hasta que
se ejecuta**, igual que un test que se dice que cubre algo. Razoné que `guard items.isEmpty`
impedía la supersesión; el razonamiento era limpio y era falso, porque con la carga en vuelo
`items` sigue vacío. El juez no razonó: escribió una sonda y la ejecutó.
