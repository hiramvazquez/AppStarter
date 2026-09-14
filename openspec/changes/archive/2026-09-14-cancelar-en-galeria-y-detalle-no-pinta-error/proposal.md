# Cancelar en Galería y Detalle no pinta error

## Why

`GalleryLogic` y `ProductDetailLogic` mandan `APIError.Category.cancelled` al `default: .unknown`
de su `mapError`, y ninguno de sus dos enums tiene caso de cancelación:

```
GalleryLogic.swift:86-93        default: return .unknown      ← .cancelled cae aquí
ProductDetailLogic.swift:102-109 default: return .unknown      ← igual
```

Consecuencia visible para el usuario: **cancelar una carga en la galería o en la ficha de
producto pinta un error a pantalla completa con «Reintentar»** — porque `.unknown` es
reintentable y `AppCancellationRecognizer` no lo reconoce como cancelación, así que
`BaseViewModel` lo presenta. Ofrecer «Reintentar» sobre algo que el usuario acaba de cancelar
invita a deshacer la decisión que acaba de tomar.

Es un incumplimiento de un requisito **vivo**: `plataforma` → «Una cancelación que se lanza no se
le presenta al usuario como error» exige cuatro cosas a toda feature cuya `Logic` lance un error
de dominio venido de la red, y estas dos incumplen las cuatro.

Lo encontró el revisor durante el cambio `un-solo-error-para-products-y-search`, que lo dejó
anotado como preexistente y fuera de su alcance.

## What Changes

Las dos features siguen el patrón que `CartFeature` ya tiene, cláusula por cláusula:

- **`GalleryError` y `ProductDetailError`** ganan un caso `cancelled`, con su `isRetryable ==
  false` y su `screenError` propio («Cancelado»), como `CartError`.
- **Sus dos `mapError`** traducen `.cancelled` a ese caso en vez de dejarlo caer en `.unknown`.
- **Sus dos ViewModels** capturan la cancelación, devuelven la fase a un estado del que se pueda
  salir —solo si su `Task` sigue viva— y la relanzan, igual que `CartViewModel`.
- **`App/AppCancellationRecognizer`** registra los dos casos nuevos; su lista pasa de dos tipos a
  cuatro.
- **Tests**: cada feature fija que la cancelación del transporte mapea a `.cancelled` y que la
  pantalla no queda en error ni colgada en `.loading`; `AppTests/CancellationRecognizerTests`
  añade los dos tipos.

**No adoptan `CatalogError`**, y la razón es la misma que aquel acuerdo dejó escrita: no
comparten el conjunto de casos. `GalleryError` tiene `notFound` y `ProductDetailError` además
`favoriteStorageFailure`. Añadirlos a `CatalogError` sería inventar estados que Products y Search
no usan.

## FUERA de alcance

- **`CatalogError` y las features que ya lo usan.** No se tocan.
- **`UploadsError.captureCancelled`**, que el requisito deja fuera a propósito: no viene de la
  red y su pantalla la presenta como resultado.
- **`DiagnosticsFeature`**, que guarda la cancelación como dato y no la lanza.
- **Las features restantes, que son tres y están medidas:** `ProfileLogic`, `LoginLogic` y la
  ruta de red de `UploadsLogic` siguen con `default: .unknown` y sin caso de cancelación, así que
  arrastran el mismo bug. `SettingsError` está exento por construcción —nunca ve un `APIError`— y
  `Diagnostics` porque guarda la cancelación como dato en vez de lanzarla. Van en su propio
  acuerdo, ya decidido con el owner.

  *Aquí ponía «si alguna lanza cancelación de red sin caso propio», un condicional que nadie
  había evaluado y que costaba el mismo `grep` que el requisito ya publica. Lo midió el juez. Sin
  el recuento, el próximo lo vuelve a descubrir — que es justo lo que este acuerdo dice querer
  evitar.*
- **Unificar `CartError` y `GalleryError`.** Comparten los cinco casos en el mismo orden, y por
  eso su `mapError` e `isRetryable` son idénticos — pero **su `screenError` no**: Cart devuelve
  «Sin carrito / No encontramos el carrito de esta cuenta.» para `.notFound` donde Gallery usa
  `ErrorCopy.NotFound`. Unificarlos **no es un renombrado**: exige decidir qué pasa con esa copy.
  Va en su propio acuerdo, y nace con esa decisión escrita en vez de descubrirla a mitad.

  *Este bullet decía «son ya el mismo enum», y era falso justo donde decide el trabajo. Lo
  cazaron el juez y el revisor por separado, los dos midiendo el `screenError`.*

## Enmienda del 2026-09-14: dos requisitos vivos que este cambio degradaba

La revisión encontró que el arreglo empeoraba dos `SHALL` de `plataforma`, y los dos se cierran
aquí porque **los empeoró este cambio**, no por «ya que estamos»:

- **«Dónde vive un helper de test compartido»**, y son **dos** helpers:
  - `RecognizerDePrueba` estaba copiado en tres targets y este cambio lo dejaba en cinco. Pasa a
    `PlatformTestSupport` y se quitan las cinco copias. El detector no lo ve —cuerpo de una
    línea—, que es justo por qué el requisito existe.
  - `Puerta`, la espera que deja una carga en vuelo, estaba solo en Cart y los dos tests nuevos
    la duplicaron: tres copias. Esta **sí** la vio el detector, con dos grupos —uno por método—,
    que es cómo se cazó. Pasa también a `PlatformTestSupport`, y con eso los dos grupos
    desaparecen: no llegan al recuento de abajo.

  Los dos salen del mismo sitio: al escribir los tests copié el patrón de Cart en vez de
  extraerlo. Es la regla que este repo inyecta en cada turno —«antes de escribir una función,
  busca si ya existe»— incumplida dos veces en el mismo cambio.
- **«Un texto de error que ven dos pantallas se escribe una vez»**: el par «Cancelado / La
  operación se canceló.» estaba en dos sitios y este cambio lo dejaba en cuatro. Pasa a
  `ErrorCopy.Cancelled`, en `Domain`, y lo usan los cuatro.

  *El bullet original decía que ese texto estaba «en tres sitios» y lo dejaba fuera de alcance
  por eso. El recuento era falso —se me escapó `DiagnosticsModels`— y con cuatro consumidores la
  excusa ya no describía el caso. Lo midió el juez.*

**Alcance añadido, declarado:** `Packages/Platform/Sources/PlatformTestSupport/RecognizerDePrueba.swift`
(nuevo), `Domain/ErrorCopy.swift`, `CartFeature/CartLogic.swift`,
`DiagnosticsFeature/DiagnosticsModels.swift` y los tres targets de test que tenían copia.

Y un tercer hallazgo, de código: **el `if !Task.isCancelled` de los dos ViewModels nuevos no lo
cubría ningún test** —la mutación sobrevivía—, mientras las otras tres features sí lo fijan. Se
añade el test de «carga superada por otra» en las dos, con el mismo mecanismo de puerta que usa
Cart.

## Criterios de aceptación

- [ ] `GalleryError` y `ProductDetailError` SHALL tener un caso de cancelación con
      `isRetryable == false`.
- [ ] Sus `mapError` SHALL traducir `APIError.Category.cancelled` a ese caso:
      `grep -A8 'static func mapError'` en los dos ficheros muestra `case .cancelled`.
- [ ] `AppCancellationRecognizer` SHALL reconocer los dos casos nuevos, y
      `AppTests/CancellationRecognizerTests` SHALL ponerse rojo si se quita cualquiera de ellos.
- [ ] Cada feature SHALL tener un test que falle si su `mapError` deja de traducir la
      cancelación, y otro que falle si su pantalla queda en error o colgada en `.loading` tras
      cancelar.
- [ ] `/kit-verifica` en verde. El detector pasa de 3 grupos a 4, y los dos grupos nuevos SHALL
      quedar declarados aquí con su medición, no resueltos en este cambio.

      *Enmienda del 2026-09-14, medida después de implementar. El criterio decía «seguir en 3
      grupos sin ninguno nuevo» y es falso: al darle a Gallery y ProductDetail el mismo caso
      `.cancelled` que ya tenía Cart, sus cuerpos convergen con los de Cart —que es lo que pasa
      cuando tres features cumplen la misma norma—.*

      *Los dos grupos son `3450e859ac` (el `mapError` de Cart, Gallery y ProductDetail, ahora
      idéntico en los tres) y `61cb3a5ed6` (el `isRetryable` de Cart y Gallery). Y la medición
      que importa, porque es la que decide qué hacer con ellos: **`CartError` y `GalleryError`
      son ya el mismo enum** —`offline notFound server cancelled unknown`, en el mismo orden—,
      igual que lo eran `ProductsError` y `SearchError` antes de `CatalogError`.*

      *No se unifican aquí, y la razón es la misma que aquel acuerdo dejó escrita: sería ampliar
      el alcance a dos features que este cambio no venía a tocar, y `ProductDetailError` no
      encaja porque tiene `favoriteStorageFailure`. La unificación honesta es Cart+Gallery, y
      es otro cambio con su propio acuerdo. Queda escrito para que no se descubra otra vez.*
- [ ] El archlint SHALL seguir en verde.

## Presupuesto

Toca dos features, sus tests y la cáscara de la app, y lo que se arregla es el cumplimiento de un
requisito vivo con cuatro cláusulas — que es justo lo que un juez comprueba criterio por
criterio. **Una pasada de revisor y una de juez.** Si la segunda solo devuelve prosa, se para.
