# Un caso nuevo no hereda «reintentable» en silencio

## Why

Al extraer `isRetryable` al default de `TransportMappable` —escrito por exclusión, `self != .notFound
&& self != .cancelled`— se perdió una garantía que nadie sustituyó: **el `switch` exhaustivo que
obligaba a decidir**.

Antes, añadir un caso a `CartError`, `GalleryError` o `ProductDetailError` **no compilaba** hasta
clasificarlo. Ahora hereda `true` sin que nadie pregunte. El caso concreto que lo hace visible lo
dio el revisor de `92d6d46`: añade `unauthorized` a `GalleryError` y la app ofrece «Reintentar»
sobre un 401 —que no va a funcionar nunca— con los 193 tests en verde.

Quedó declarado como deuda en aquel acuerdo, con la mitigación que había: un aviso en el comentario
de los tres enums. Un aviso no es un detector, y esto lo cierra.

## What Changes

- **Los tres enums pasan a ser `CaseIterable`.**
- **El `switch` exhaustivo vuelve, pero al TEST**, dentro del test de reintentabilidad que cada
  feature ya tiene: recorre `allCases` y clasifica cada uno. Si alguien añade un caso sin
  clasificarlo, **el test no compila** — `error: switch must be exhaustive`.

Eso recupera la garantía en el sitio correcto: el compilador vuelve a obligar a decidir, sin
devolver a los tres `Logic` la duplicación que `92d6d46` acaba de quitarles.

Y hace algo que el `switch` de producción no hacía: al comparar `allCases` contra la clasificación
explícita, comprueba además que **el default heredado y la decisión de la feature coinciden**.

## Capabilities

### Modified Capabilities

- `plataforma`: el requisito «La traducción del transporte se escribe una vez» gana una cláusula.
  Hoy fija qué hereda cada feature; le falta decir que heredar no exime de clasificar los casos
  propios, que es justo el hueco por el que se cuela este fallo.

## Impact

- `Packages/Features/Sources/CartFeature/CartLogic.swift`,
  `GalleryFeatureCore/GalleryLogic.swift`, `ProductDetailFeature/ProductDetailLogic.swift` —
  `CaseIterable` y el aviso del comentario, que pasa de ser la mitigación a ser una nota.
- `CartFeatureTests/CartModelTests.swift`, `GalleryFeatureTests/GalleryLogicTests.swift`,
  `ProductDetailFeatureTests/ProductDetailLogicTests.swift` — el `switch` exhaustivo dentro del
  test de reintentabilidad que ya tienen.

No se añade ningún fichero ni ninguna dependencia.

## Fuera de alcance

- **`UploadsError`, `CatalogError` y `DiagnosticsError`.** Los tres conservan su `switch`
  exhaustivo propio en producción, así que nunca perdieron la garantía: no les aplica.
- **Cambiar la forma del default** (volver a enumerar casos en `TransportMappable`). Es lo que
  permite que `ProductDetailError.favoriteStorageFailure` herede sin que el protocolo lo conozca,
  y deshacerlo devolvería la duplicación que `92d6d46` quitó.
- **El `.untrustedServer` que hereda reintentable** y que `DiagnosticsError` trata como no
  reintentable. Es una discrepancia real, ya declarada y fijada por un test; reconciliarla es otra
  decisión con su propia medición.

## Criterios de aceptación

- [x] `CartError`, `GalleryError` y `ProductDetailError` SHALL ser `CaseIterable`.
- [x] Cada uno SHALL tener, en su test de reintentabilidad, un `switch` exhaustivo sobre
      `allCases` que clasifique todos sus casos.
- [x] Añadir un caso a cualquiera de los tres SHALL **romper la compilación** de su test. Se
      comprueba añadiéndolo de verdad y viendo `error: switch must be exhaustive`, no leyendo el
      código.

      *Comprobado el 2026-09-14, y a la segunda. La primera medición era engañosa: el error salía
      en `GalleryLogic.swift:47`, el `switch` de `screenError`, que ya era exhaustivo ANTES de
      este cambio — el compilador paraba ahí sin llegar al test. Repetido dándole al caso nuevo su
      arm en `screenError`: el producto compila y es el test el que corta
      (`GalleryLogicTests.swift:91:13`). Esa es la barrera que este cambio añade, y la que impide
      lo que antes pasaba: arreglar el `screenError` y dejar `isRetryable` heredado en silencio.*
- [x] El test SHALL comparar la clasificación explícita contra `isRetryable`, de modo que también
      falle si el default heredado deja de coincidir con lo que la feature decide.
- [x] El detector NO SHALL ganar ningún grupo. Hoy son 2; se mide contra HEAD y se declara aquí.

      *Medido el 2026-09-14 contra un worktree limpio de `4a9c4a5`: **2 antes, 2 después**, y son
      los mismos dos —`8389af4e6c` y `1f074820d8`—, ambos ya declarados fuera de alcance.*

      *Aquí añadía que así se evitaba el grupo `0d7f0aa593` que «el prototipo advertía». Eso era
      **falso**, y la corrección importa porque desmonta un mérito que este cambio no tiene: ese
      grupo no habría aparecido de ninguna forma. Mi prototipo puso el tipo en la FIRMA de la
      función, que el detector no huella —solo huella lo que va entre las llaves—, así que comparó
      cuerpos idénticos. En la alternativa real el tipo va dentro del cuerpo
      (`CartError.allCases`) y el detector no agrupa. Lo cazó el revisor; comprobado después
      aislando la variable.*
- [x] `/kit-verifica` en verde y el archlint sin errores.

## Presupuesto

Tres enums, tres tests y una cláusula; ninguna pieza nueva. Lleva `design.md` porque la decisión
—dónde poner el `switch`— tuvo alternativas reales que descartar. **Una pasada de revisor.**

*Y una nota sobre cómo se descartaron, porque el revisor la corrigió: de las dos alternativas,
solo una cae por un argumento sólido —un closure no puede dar exhaustividad de compilador al
llamante—. La otra, el test propio por feature, se descartó contra una medición equivocada y en
realidad solo sobra por añadir superficie. La decisión aguanta; el razonamiento que la sostenía,
no, y está corregido arriba en vez de dejarlo escrito como si hubiera acertado.*
