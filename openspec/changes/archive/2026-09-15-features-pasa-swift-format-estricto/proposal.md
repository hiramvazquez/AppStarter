# El formato de `Packages/Features` pasa `swift format lint --strict`

## Why

CI ejecuta en cada paquete, en el paso «SwiftLint --strict + swift-format lint (Packages/<pkg>)»,
primero `swiftlint lint --strict …` y después:

```sh
swift format lint --strict --configuration ../../.swift-format --recursive Sources Tests
```

Medido el 2026-09-15 con esa orden y swift-format 6.3.3:

- **0 avisos** en `Packages/Platform`.
- En `Packages/Features`, **78** sobre `dfc20bc` y **84** sobre `94deb9c`, que es la base de este
  cambio (ver «Renegociado…»). Siempre en los mismos 14 ficheros.

Sobre `94deb9c`, por regla:

- 30 `Indentation`, 24 `AddLines` y 20 `Spacing`;
- 5 `TrailingComma` y 4 `OrderedImports`;
- 1 `RemoveLine`.

Hoy ese fallo está **tapado**. El paso corre con `bash -e` y SwiftLint va delante. En el último run
de CI en `main` (`35006556028`, 2026-09-15), SwiftLint sale con código 2 en `Features` y swift-format
no llega a ejecutarse: el log no tiene ningún aviso suyo. `lint-estricto-y-reglas-de-los-kits-en-contexto`
(`94deb9c`) arregla ese SwiftLint, pero con él solo el paso seguirá en rojo por estos 84. Y
`/kit-verifica` no lo ve: ningún paso de `kit.conf` ejecuta swift-format.

## What Changes

- Sobre `94deb9c`, en `Packages/Features` se ejecuta una vez
  `swift format format --in-place --configuration ../../.swift-format --recursive Sources Tests`.
  El resultado se queda como lo deja la herramienta, sin retoques a mano.
- Cambian estos 14 ficheros, todos bajo `Packages/Features/`, y ninguno más (avisos sobre
  `94deb9c`):

  | Fichero | Avisos |
  |---|---|
  | `Sources/ProductsFeature/ProductsViewModel.swift` | 7 |
  | `Sources/SearchFeature/SearchViewModel.swift` | 7 |
  | `Tests/CartFeatureTests/CartLogicTests.swift` | 19 |
  | `Tests/CartFeatureTests/CartViewModelTests.swift` | 2 |
  | `Tests/CartFeatureTests/Services/CartServiceTests.swift` | 8 |
  | `Tests/CartFeatureTests/Services/CartUpdateServiceTests.swift` | 18 |
  | `Tests/GalleryFeatureTests/GalleryViewModelTests.swift` | 2 |
  | `Tests/LoginFeatureTests/LoginViewModelTests.swift` | 2 |
  | `Tests/ProductDetailFeatureTests/ProductDetailViewModelTests.swift` | 2 |
  | `Tests/ProductsFeatureTests/ProductsLogicTests.swift` | 1 |
  | `Tests/ProductsFeatureTests/ProductsViewModelTests.swift` | 9 |
  | `Tests/ProfileFeatureTests/ProfileViewModelTests.swift` | 2 |
  | `Tests/SearchFeatureTests/SearchLogicTests.swift` | 1 |
  | `Tests/SearchFeatureTests/SearchViewModelTests.swift` | 4 |

- Qué hace el formateador, visto en un ensayo sobre una copia (2026-09-15):
  - vuelve a sangrar el comentario que abre el closure de `performLoad` en `ProductsViewModel` y
    `SearchViewModel`;
  - deja dos espacios antes de un `//` a final de línea, en vez de alinearlos en columna;
  - reparte en varias líneas los argumentos de varios `#expect(…)`, de `Data("""…""".utf8)` y de un
    `.init(…)`;
  - quita la coma final de los arrays de varias líneas;
  - pone `import Foundation` antes de `import Networking` en cuatro tests;
  - quita la línea en blanco del final de `ProductsViewModelTests.swift`.
- SwiftLint: sobre `94deb9c`, desde la raíz sale con código 0 y sin salida, y así tiene que seguir.

Ningún cambio de comportamiento. No es **BREAKING**.

## Capabilities

### New Capabilities

Ninguna.

### Modified Capabilities

Ninguna. Es formato de código: no cambia ningún requisito. Lleva `skip_specs: true`.

## Renegociado el 2026-09-15: la base es `94deb9c`, no `main`

- **Qué decía el acuerdo.** Entraba primero `lint-estricto…` y este cambio se rehacía «sobre
  `main`» cuando aquel estuviera dentro (`design.md` y tarea 4.1).
- **Qué pasó.** Al retomar, `lint-estricto…` estaba commiteado como `94deb9c`, hijo directo de
  `dfc20bc`, en su propia rama. No estaba archivado, y `main` y `origin/main` seguían en `dfc20bc`.
- **Qué se acuerda.** El owner eligió partir de `94deb9c` en vez de esperar:
  - esta rama se trae a `94deb9c` con fast-forward, y el formato se rehace encima;
  - **esta rama no se fusiona en `main` antes que `lint-estricto…`**, porque se llevaría `94deb9c`
    sin su revisión ni su archivado;
  - antes de fusionarla, `Packages/Features/Sources` y `Packages/Features/Tests` en `main` tienen
    que ser iguales que en `94deb9c`, que es lo que mira la orden de formato. Si la revisión o el
    archivado de aquel cambio tocan algo ahí, se rehace el formato con la misma orden.
- **Precisado el mismo día, en la tarea 4.2.**
  - La regla decía «`Packages/Features`» entero, y así no se podía cumplir.
  - `main` avanzó a `8231924` con otra rama, que trae `README.md` y una línea de
    `Packages/Features/Package.swift`, pero no toca `Sources` ni `Tests`.
  - Por eso la comparación se ciñe a lo que mira la orden de formato. `lint-estricto…` sigue fuera
    de `main`.
- **Qué cambia en las cifras.**
  - Avisos de swift-format: de 78 a 84, en los mismos 14 ficheros. `CartUpdateServiceTests.swift`
    pasa de 12 a 18.
  - Línea base de SwiftLint: de 20 a 0.
  - Los resultados de la primera pasada, sobre `dfc20bc`, quedan anotados en la tarea 4.1.

## Coordinación con `lint-estricto-y-reglas-de-los-kits-en-contexto`

Ese cambio está commiteado como `94deb9c` en su rama, sin archivar y sin fusionar en `main`
(2026-09-15). Deja swift-format fuera de alcance, y los dos juntos ponen en verde el paso de CI de
`Features`.

Coinciden en tres ficheros: `ProductsViewModel.swift`, `ProductsViewModelTests.swift` y
`CartUpdateServiceTests.swift`. Las ediciones de aquel cambio ya están en la base, y este solo
formatea encima. Este cambio no edita los artefactos de aquel: ese acuerdo es de quien lo lleva.

## Fuera de alcance

- **`.swift-format` y `.github/workflows/ci.yml`**: ni reglas, ni versión, ni la orden del paso.
- **`Packages/Platform`**, que da 0 avisos con la orden de CI.
- **Las violaciones de SwiftLint**, que arregla `lint-estricto…`, y **`Scripts/check-showcase.sh`**,
  cuyo job sigue en rojo por su cuenta.
- **Revisar, archivar o fusionar `lint-estricto…`**, y editar sus artefactos.
- **Meter swift-format en `kit.conf`.** La consecuencia, dicha: `/kit-verifica` sigue sin ver el
  formato, y un cambio posterior puede volver a romperlo con la firma en verde.
- **Retocar a mano** lo que deja el formateador, o cambiar código o comentarios.
- **Lo que la orden de CI no mira**: en `Packages/Features`, lo que queda fuera de `Sources` y
  `Tests` (como `Package.swift`); y `App/`, `AppTests`, `AppSnapshotTests` y `AppUITests`.

## Criterios de aceptación

- [x] La rama parte de `94deb9c`: `git merge-base --is-ancestor 94deb9c HEAD` sale con código 0, y
      `git log 94deb9c..HEAD` no trae commits de otros cambios. *(medido: código 0; HEAD es
      `94deb9c` y no hay commits entre medias)*
- [x] En `Packages/Features`, `swift format lint --strict --configuration ../../.swift-format
      --recursive Sources Tests` sale con código 0 y sin salida. *(tarea 2.2)*
- [x] La misma orden en `Packages/Platform` sigue saliendo con código 0 y sin salida. *(tarea 2.2)*
- [x] Lo mismo con la versión de CI. En el run `35006556028` fue Swift 6.2.4, y swift-format se
      compila desde su tag `swift-6.2.4-RELEASE`. Con él, la orden da 0 avisos en los dos
      paquetes, y formatear la copia de antes deja los mismos ficheros que la versión local.
      *(tarea 2.4)*
- [x] `git diff --name-only` lista exactamente los 14 ficheros de la tabla. *(tarea 2.1)*
- [x] El diff es solo formato. Se comprueba con un script de un solo uso que compara cada fichero
      antes y después: (a) sin espacios, sin la coma final antes de `]` o `)` y con los `import`
      ordenados, el texto es idéntico; (b) cada literal multilínea `"""` da los mismos bytes.
      Salidas anotadas en `tasks.md`. *(tareas 3.1 y 3.2: 14/14 y 3/3)*
- [x] Una segunda pasada de `swift format format` con la misma orden no cambia ningún fichero.
      *(tarea 2.3)*
- [x] `swiftlint lint --strict --quiet` desde la raíz sigue saliendo con código 0 y sin salida,
      como sobre `94deb9c`. *(tarea 3.3)*
- [x] Tras `/kit-verifica`, `git status --short AppSnapshotTests/__Snapshots__` sale vacío: no se
      regraba ninguna referencia. *(tarea 5.2)*
- [x] Queda anotado en `tasks.md` si `main` contiene ya `94deb9c`. Si no, el cierre recuerda que esta
      rama no se fusiona antes que `lint-estricto…`. *(tarea 4.2: `main` está en `8231924`, que no lo
      contiene)*
- [x] `/kit-verifica` en verde. *(tarea 5.2: segunda corrida, firma `c1c9a3e53096…`)*

## Impact

| Fichero | Qué cambia |
|---|---|
| los 14 ficheros de la tabla, bajo `Packages/Features/` | solo formato, sobre `94deb9c` |

Sin cambios: `.swift-format`, `.swiftlint.yml`, `.github/workflows/ci.yml`, `kit.conf`,
`Packages/Platform`, las specs y los artefactos de `lint-estricto…`.
