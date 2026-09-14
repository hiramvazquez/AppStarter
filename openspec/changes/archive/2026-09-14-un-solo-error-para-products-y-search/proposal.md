# Un solo error para Products y Search

## Why

`ProductsError` y `SearchError` son **el mismo enum con otro nombre**: los cuatro mismos casos
—`offline`, `server`, `cancelled`, `unknown`—, el mismo `isRetryable`, el mismo `screenError` y
el mismo `mapError(_:)`, comentarios incluidos. El detector de lógica repetida del kit los
reporta hoy en tres de sus seis grupos:

```
huella 3e49a5234c — 17 líneas, 2 copias:  ProductsLogic.swift:24 · SearchLogic.swift:24   screenError()
huella 1f074820d8 —  7 líneas, 2 copias:  ProductsLogic.swift:79 · SearchLogic.swift:71   mapError()
huella 0e7e1ad65c —  5 líneas, 2 copias:  ProductsLogic.swift:17 · SearchLogic.swift:17   isRetryable()
```

No es una coincidencia de forma: las dos features llaman al **mismo** `ProductsServicing` y
traducen sus mismos fallos. Cuando `ErrorCopy` cambió —en `unificar-textos-de-error-comunes`—
hubo que tocar los dos ficheros, y el día que haya un quinto caso de red habrá que acordarse de
los dos otra vez.

## What Changes

- **`Packages/Platform/Sources/Networking/CatalogError.swift`** (nuevo): un enum `CatalogError`
  con los cuatro casos, su `isRetryable`, su `screenError` y el mapeo desde `APIError`. Vive en
  `Networking` porque necesita `ScreenError` (de `AppFoundation`) y `APIError` (de
  `CoreNetworking`), y `Networking` es el único módulo de Platform que puede importar los dos:
  `.archlint.yml` declara `Domain: allowedImports: [Foundation]`. Ver la enmienda de abajo.
- **`ProductsLogic.swift` y `SearchLogic.swift`**: `ProductsError` y `SearchError` desaparecen;
  las dos features usan `CatalogError`.
- **Sus tests**: `ProductsLogicTests` y `SearchLogicTests` pasan a esperar `CatalogError`. Lo que
  fijan no cambia: que una cancelación del transporte mapea a `.cancelled` y no a `.unknown`, y
  que `.cancelled` no es reintentable.

## FUERA de alcance

- **Las otras nueve features que tienen su propio error.** Y no por pereza: **no comparten los
  casos**. `FavoritesError` tiene dos (`storageFailure`, `unknown`) y `CartError` cinco (añade
  `notFound`). Un enum común para las once no existe sin inventar casos que nadie usa, que es
  peor que la duplicación que arregla.
- **`GalleryLogic` y `ProductDetailLogic`**, que el detector también empareja por su `mapError`.
  Comparten el mapeo pero no el conjunto de casos; si mañana convergen, este `CatalogError` está
  puesto para adoptarlo.
- **La copia de `body()`** en `FavoritesView`, `ProductsView` y `SearchView`, que es el cuarto
  grupo del informe. Es SwiftUI y es otra decisión.
- **`ErrorCopy`**: no cambia lo que hace ni lo que expone. Este cambio lo consume.

  *Enmienda: su comentario de cabecera SÍ se tocó, y el «no se toca» de arriba era demasiado
  ancho. Ese comentario citaba `ProductsError` y `SearchError` como motivo de existir, y este
  cambio los borra: dejarlo habría sido publicar una referencia a dos tipos que ya no existen.
  Lo cazaron el juez y el revisor, los dos, en la ronda 1.*

## Criterios de aceptación

- [ ] `ProductsError` y `SearchError` NO SHALL existir: `grep -rn 'ProductsError\|SearchError'
      Packages/` no devuelve nada fuera de este acuerdo.
- [ ] Las dos features SHALL usar `CatalogError`, y `CatalogError` SHALL vivir en `Networking`.
- [ ] Los tres grupos del informe de duplicados —`screenError`, `mapError`, `isRetryable` entre
      `ProductsLogic` y `SearchLogic`— SHALL desaparecer de `/kit-duplicados`, y el cambio NO
      SHALL dejar ninguno nuevo: el informe pasará de **6 grupos a 3**.

      *Enmienda del 2026-09-14, y sale de medirlo: al unificar el tipo, los dos tests
      `cancelacionNoEsReintentable()` —uno en `ProductsLogicTests`, otro en `SearchLogicTests`—
      pasaron a tener el mismo cuerpo, porque los dos afirman ahora lo mismo sobre
      `CatalogError`. El informe daba 4 y no 3: tres grupos cerrados y **uno nuevo, introducido
      por este cambio**. El criterio original solo contaba los que desaparecen y por eso no lo
      habría visto; se le añade la segunda mitad. Lo cazó el detector del kit, no la revisión.*
- [ ] Lo que los tests fijan hoy SHALL seguir fijado: una cancelación del transporte mapea a
      `.cancelled` y no a `.unknown`, y `.cancelled` NO es reintentable. Con el mismo número de
      aserciones o más.
- [ ] `/kit-verifica` en verde: build y tests de los dos paquetes, `xcodebuild`, `AppTests` y
      `AppSnapshotTests`.
- [ ] El archlint SHALL seguir en verde: `Networking` no importa ninguna feature, y `Domain`
      sigue viendo solo `Foundation`.

## Enmienda del 2026-09-14: el alcance es mayor que el declarado

Al implementar la tarea 2 se comprobó que `ProductsError` y `SearchError` **no viven solo en la
lógica y sus tests**. Los nombran, además:

| fichero | qué hace con ellos |
|---|---|
| `ProductsViewModel.swift` | seis usos: `catch ProductsError.cancelled` y `throw` en tres flujos |
| `SearchViewModel.swift` | dos usos, el mismo patrón |
| `App/AppCancellationRecognizer.swift` | **los empareja con `CartError.cancelled`** para reconocer una cancelación |
| `ProductsViewModelTests`, `SearchViewModelTests`, `AppTests/CancellationRecognizerTests` | los usan como dobles y como aserción |

**Aquí no va un recuento de ficheros.** Lo que se toca, por sitios:
`Platform/Sources/Networking` (el tipo), `Platform/Sources/Domain` (el comentario de
`ErrorCopy`), `Platform/Tests/NetworkingTests` (su test), las dos features con sus tests, y la
cáscara `App/` con `AppTests`. Quien necesite el recuento exacto, que lo mida:
`git status --porcelain -uall`.

El alcance no crece por decisión: crece porque la propuesta se escribió sin comprobar quién más
nombraba esos tipos.

*Este párrafo llevó un número tres veces y las tres salió mal: «cinco ficheros» en la propuesta,
«nueve ficheros y tres capas» en la primera enmienda, «14 —11 modificados y 3 nuevos»— en la
segunda, cuando los nuevos son 2 de código o 5 contando el acuerdo. La tercera la escribió el
arreglo de la segunda. No se corrige contando una cuarta vez: se quita el censo, que es lo que
el juez recomendó al alcanzar su tope — un número en prosa no tiene quien lo ponga rojo.*

**Lo que cambia del acuerdo:** el `What Changes` incluye los dos ViewModels,
`AppCancellationRecognizer` y los tres ficheros de test que faltaban. Lo que NO cambia es la
solución ni el «Fuera de alcance»: las otras nueve features siguen con su error.

**Y una consecuencia que el `AppCancellationRecognizer` deja ver, y que conviene decir porque es
la mitad interesante del cambio:** hoy empareja tres tipos distintos —`ProductsError`,
`SearchError`, `CartError`— para responder a la misma pregunta. Al fundir dos de ellos, esa
lista pasa de tres a dos. `CartError` se queda, porque tiene cinco casos y no es este error.

**Por el criterio del kit, este cambio ahora SÍ pide juez**: el alcance se movió al implementar,
y toca varias capas. Se paga esa ronda.

## Presupuesto

Toca varias capas —la plataforma, dos features y la cáscara de la app—, así que por la tabla de
`docs/FLUJO.md` lleva `tasks.md` y **el juez sí aporta aquí**: hay features que se quedan fuera
a propósito, que es justo lo que un juez comprueba y un revisor no. **Una pasada de revisor y
una de juez**, y si la segunda solo devuelve prosa, se para.

*Este párrafo decía «cinco ficheros y dos capas —`Domain` y dos features—» y era el último sitio
que describía el cambio con la forma que tuvo antes de las dos enmiendas.*
