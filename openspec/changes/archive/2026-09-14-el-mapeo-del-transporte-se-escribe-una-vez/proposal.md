# El mapeo del transporte se escribe una vez

## Why

`CartError` y `GalleryError` son hoy el mismo enum con otro nombre: los cinco casos en el mismo
orden, el mismo `isRetryable` y el mismo `mapError`. Difieren en **un solo arm** de `screenError`,
el de `.notFound`.

Pero al medirlo aparece que el duplicado no son dos features, sino tres: el detector reporta
`3450e859ac` con **tres** copias idénticas de `mapError` —Cart, Gallery y `ProductDetail`— y
`61cb3a5ed6` con dos de `isRetryable`. Son los dos grupos que este repo arrastra desde que las
tres features cumplen la misma norma de cancelación.

Lo que está repetido es la **traducción del transporte al dominio**, no el tipo. Y esa traducción
tiene que mirar los trece casos de `APIError.Category`: cada copia es una oportunidad de que una
feature olvide uno.

## What Changes

- **Un protocolo nuevo en `Networking`** que exige los cinco casos y da por defecto la traducción
  desde `APIError` y el `isRetryable`. Las tres features lo conforman con una línea y **borran**
  sus `mapError` e `isRetryable`.
- **Los tres enums se quedan donde están, con su `screenError` intacto.** Es la decisión que ya
  estaba tomada —el `screenError` se queda en cada feature— y la que conserva «Sin carrito».

**No se fusionan los tipos, y la razón está medida.** `screenError` es una propiedad del enum: un
enum compartido tiene uno solo. Fusionar `CartError` y `GalleryError` obligaría a elegir entre
«Sin carrito / No encontramos el carrito de esta cuenta.» y `ErrorCopy.NotFound`, y hay un test
que lo prohíbe —`CartModelTests.missingCartHasItsOwnCopy`— con su motivo escrito: *«"Este producto
ya no está disponible" aquí sería mentira: lo que no existe es el carrito, no un producto.»*

## Capabilities

### New Capabilities

Ninguna.

### Modified Capabilities

- `plataforma`: gana un requisito que fija dónde vive la traducción del transporte y qué features
  la comparten. Es comportamiento a nivel de spec —hoy cada feature promete ese mapeo por su
  cuenta y pasa a prometerlo la plataforma—, igual que pasó cuando `CatalogError` absorbió a
  Products y Search.

## Impact

- `Packages/Platform/Sources/Networking/` — el protocolo nuevo.
- `Packages/Features/Sources/CartFeature/CartLogic.swift`,
  `GalleryFeatureCore/GalleryLogic.swift` y `ProductDetailFeature/ProductDetailLogic.swift` —
  pierden `mapError` e `isRetryable`, ganan una conformidad.
- Sus tres ficheros de test, que hoy fijan ese mapeo por feature y deben seguir haciéndolo.

- `Packages/Features/Package.swift` — **alcance añadido, declarado el 2026-09-14 al implementar.**

*Aquí ponía «las tres features ya dependen de `Networking`, así que no se añade ninguna
dependencia», y es **falso**. Medido con `awk` sobre el manifiesto: solo `ProductDetailFeature`
la declara; `CartFeature` y `GalleryFeatureCore` declaran únicamente `AppFoundation`,
`CoreNetworking` y `Domain`, y sus `Logic` no importan `Networking`. Lo escribí por analogía con
`CatalogError` —que sí lo usan features que ya dependían de él— sin comprobarlo en este caso.*

*Consecuencia real: dos targets necesitan ganar la dependencia, y esa edición cae DENTRO de los
marcadores `archinit:features-begin/end`, cuyo encabezado declara que `generate-feature` es la
única herramienta que los toca. No es un detalle de trámite: es la diferencia entre un cambio
mecánico y uno que toca el manifiesto que otra herramienta se atribuye.*

*Resuelto midiendo, no por conveniencia. `generate-feature` **no puede** hacerlo: `AGENTS.md:85-88`
dice que su competencia es dar de alta un target nuevo y su test target entre los markers, no
añadir dependencias a targets que ya existen, y además no está disponible aquí. Y hay precedente
exacto en este repo: **`86bb6a4`** —«waitUntil deja de estar escrito dos veces», el mismo tipo de
extracción que ésta— añadió a mano `.product(name: "PlatformTestSupport", package: "Platform")` a
un target dentro de los markers. El «nunca a mano» del encabezado gobierna el ALTA de targets, que
es lo que la herramienta gestiona; esto no lo es.*

## Fuera de alcance

- **Fusionar los tipos de error.** Por lo dicho arriba: exigiría decidir la copy, y esa decisión
  ya está tomada en contra.
- **`CatalogError`.** No se toca y no absorbe a nadie. Necesitaría `notFound`, y el escenario «Una
  feature con otros casos» de `plataforma` lo prohíbe explícitamente: *«no se le añaden casos a
  `CatalogError` para acomodarla»*.
- **El grupo `1f074820d8`** —`UploadsLogic.mapError` ≡ `CatalogError.from`—. Son la forma **sin**
  `notFound`, así que no conforman este protocolo sin inventarles un caso. Queda como estaba, ya
  declarado en el acuerdo anterior.
- **`FavoritesError` y `SettingsError`**, que no traducen `APIError`.

## Criterios de aceptación

- [x] SHALL existir en `Networking` un protocolo que dé la traducción desde `APIError` y el
      `isRetryable` por defecto, y las tres features SHALL conformarlo.
- [x] `CartLogic`, `GalleryLogic` y `ProductDetailLogic` NO SHALL declarar `mapError` ni
      `isRetryable` propios: `grep -c 'func mapError'` en los tres da 0.
- [x] El `screenError` de las tres SHALL quedar **byte a byte igual**, y
      `CartModelTests.missingCartHasItsOwnCopy` SHALL seguir en verde sin tocarlo.
- [x] Cada feature SHALL conservar un test que falle si su mapeo deja de traducir `.cancelled` y
      otro que falle si `.notFound` pasa a ser reintentable.
- [x] Una categoría que ninguna feature enumera —`.decoding`, `.timeout`— SHALL seguir cayendo en
      `.unknown`, con un test que lo fije en el nivel compartido.
- [x] El detector SHALL perder los grupos `3450e859ac` y `61cb3a5ed6`, medido contra HEAD en un
      worktree limpio. Hoy son 4 grupos; el resultado se declara aquí con su medición.

      *Medido el 2026-09-14 contra un worktree limpio de `842e096`: **4 antes, 2 después**. Se
      fueron exactamente los dos previstos y **no apareció ninguno nuevo** — al contrario que en
      el cambio anterior, donde la extracción fabricó un grupo al hacer converger otros cuerpos.
      Quedan `8389af4e6c` (el `body()` de tres vistas) y `1f074820d8` (Uploads ≡
      `CatalogError.from`), los dos declarados fuera de alcance y sin tocar.*

      *Y la comprobación que importa más que el recuento: las tres features conservan sus tests y
      **siguen siendo ellas las que se ponen rojas** si el default heredado deja de valer.
      Probado por mutación — la tabla está en `tasks.md`, tarea 8.*
- [x] `/kit-verifica` en verde y el archlint sin errores.

## Ronda 1 del revisor: AMBER, cuatro hallazgos

**1. Arreglado, y era grave: un criterio estaba marcado como cumplido y era FALSO.** El criterio
pedía que *cada* feature conservara un test que falle si `.notFound` pasa a ser reintentable.
Solo lo tenía Cart. Gallery y ProductDetail no lo afirmaban en ningún sitio, así que para
`.notFound` la promesa de `design.md` —«si el default deja de valer para una, se pone roja ahí»—
era falsa en dos de tres. Se añaden los dos asserts.

*Y lo que más vale de este hallazgo: **mi prueba de mutación no podía cazarlo**. Mutar
`isRetryable` a `true` rompe también el assert de `.cancelled`, que sí está en las tres, así que
las tres se ponían rojas y la tabla parecía confirmar lo que no era. La mutación que discrimina
es quitar solo `notFound` del default. Una mutación demasiado gruesa no prueba lo que parece
probar.*

**2. Arreglado: el código citaba un test que no existía.** `ProductDetailLogic` decía que la
herencia de `favoriteStorageFailure` la convertía en contrato «el test de aquí», y ese test no
estaba en ningún sitio. Antes del cambio lo forzaba el `switch` exhaustivo; al extraer el default
esa garantía se perdió sin que nadie la sustituyera. Ahora existe, y el comentario lo nombra.

**3. Declarado, con mitigación parcial: lo que se perdió es el compilador, no un test.** Con el
`switch` exhaustivo, añadir un caso a cualquiera de los tres enums NO compilaba hasta decidir su
reintentabilidad. Ahora un caso nuevo hereda `true` en silencio —un `unauthorized` en Gallery
ofrecería «Reintentar» sobre un 401 con los tests en verde—. No hay red automática que lo cace, y
cambiar la forma del default rompería lo que hace funcionar a ProductDetail sin sobrescribir. La
mitigación es que los tres enums lo avisen **donde lo lee quien añade el caso**, y eso se hace.
Queda escrito que es un aviso, no un detector.

**4. Arreglado: la spec base describía una función que este cambio borró.** La cláusula 1 del
requisito «Una cancelación que se lanza…» decía «su `mapError` SHALL traducir…», y las tres
features ya no tienen `mapError`. El delta era ADDED-only, así que nadie la tocaba. Se enmienda
con un `MODIFIED`, que es lo que hizo el precedente cuando `CatalogError` absorbió a Products y
Search. `openspec validate --strict` pasaba igual: no compara la spec con el código.

**Del hueco del test compartido:** se añade `.untrustedServer`, que caía en `.unknown` sin que
nadie lo comprobara. El assert **no bendice** ese comportamiento —un pin TLS rechazado hereda
«Reintentar» sobre algo que no va a funcionar nunca, y `DiagnosticsError` sí lo trata como no
reintentable—: fija cuál es hoy para que no cambie sin querer. Reconciliar las dos convivencias
es otra decisión, con su propia medición.

**No se aplica, y se dice por qué:** el revisor observa que `from(_:)` pasa de `private static` a
API pública de los tres enums, así que alguien podría fabricar errores de dominio fuera de la
frontera Logic/Service (M1). Ningún llamante lo hace hoy, y cerrarlo exigiría envolver el
protocolo o cambiar su visibilidad — otro cambio. Queda anotado.

## Presupuesto

Toca tres features y la plataforma, y mueve comportamiento que hoy está escrito cinco veces —por
eso lleva `design.md`, que es donde se justifica el protocolo frente a las alternativas. **Una
pasada de revisor.** El juez solo si el alcance se mueve al implementar.
