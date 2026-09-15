# Las reglas de los kits en contexto, y SwiftLint estricto dentro de la verificación

## Why

Dos huecos entre lo que el agente tiene delante y lo que la verificación comprueba.

**Las reglas de los kits no están en contexto.** AppFoundation y CoreNetworking traen su propio
`AGENTS.md`, y AppFoundation un `Testing.md` con cómo se testea cada capa. Viven en el checkout
de SPM, no en el repo, así que en cada sesión hay que ir a buscarlos con `/kit-doc` y nada
garantiza que se lean. `CLAUDE.md` solo importa el `AGENTS.md` del proyecto.

**SwiftLint no forma parte de `/kit-verifica`.** La firma sale en verde con violaciones que CI
rechaza. Medido el 2026-09-15 con `swiftlint lint --strict --quiet` desde la raíz:

- **20 violaciones** en todo el repo, y una de ellas es un error incluso sin `--strict`
  (`App/OfflineFixtures.swift:140`, una línea de 192 caracteres).
- **5** en el alcance que lintea CI (`Sources` y `Tests` de los paquetes). Dos de ellas las metió
  el cambio anterior, `cambiar-cantidad-y-quitar-del-carrito`, con `/kit-verifica` en verde:
  `CartMocks.swift:34` (tupla de 3) y `CartUpdateServiceTests.swift:94` (124 caracteres).
- El último run de CI en `main` (`35006556028`, 2026-09-15) falla, entre otros, en el paso
  «SwiftLint --strict + swift-format lint (Packages/Features)».

## What Changes

- `CLAUDE.md` importa, después de `@AGENTS.md`, los tres documentos desde el checkout de SPM de
  `Packages/Platform`:
  - `Packages/Platform/.build/checkouts/AppFoundation/AGENTS.md`
  - `Packages/Platform/.build/checkouts/CoreNetworking/AGENTS.md`
  - `Packages/Platform/.build/checkouts/AppFoundation/Sources/AppFoundation/Documentation.docc/Testing.md`

  Y dice dos cosas junto a ellos: que donde discrepen con el `AGENTS.md` del proyecto, gana el del
  proyecto; y que en un clon recién hecho esos ficheros no existen hasta resolver los paquetes.
- `kit.conf` gana un paso `SwiftLint · --strict` que lintea **todo el repo** con el
  `.swiftlint.yml` de la raíz, antes de los builds.
- `.swiftlint.yml` añade `.claude` a su `excluded`. Sin eso, la orden sin rutas lintea también los
  worktrees que Claude Code crea en `.claude/worktrees/`, que son copias completas del repo, y el
  paso saldría en rojo mientras haya uno abierto. No cambia ninguna regla ni umbral.
- Se corrigen las 20 violaciones en el código, sin añadir ningún `swiftlint:disable`:

  | Fichero | Violaciones |
  |---|---|
  | `AppSnapshotTests/GallerySnapshotTests.swift` | 3 × `force_unwrapping` (URLs literales) |
  | `AppSnapshotTests/UploadsSnapshotTests.swift` | 1 × `force_unwrapping` (PNG en base64) |
  | `AppSnapshotTests/CartSnapshotTests.swift` | 1 × `function_body_length` (`StubLogic.load`, 60 líneas) |
  | `App/OfflineFixtures.swift` | 2 × `force_unwrapping`, 1 × `function_body_length` (`makeTransport`, 63), 2 × `line_length` (192 y 128) |
  | `AppTests/CancellationRecognizerTests.swift` | 4 × `identifier_name` (`r`) |
  | `AppUITests/SettingsUITests.swift` | 1 × `function_body_length` (62 líneas) |
  | `Packages/Features/Tests/CartFeatureTests/Mocks/CartMocks.swift` | 1 × `large_tuple` |
  | `Packages/Features/Tests/CartFeatureTests/Services/CartUpdateServiceTests.swift` | 1 × `line_length` (124) |
  | `Packages/Features/Tests/ProductsFeatureTests/ProductsViewModelTests.swift` | 2 × `identifier_name` (`p`) |
  | `Packages/Features/Sources/ProductsFeature/ProductsViewModel.swift` | 1 × `todo`, falso positivo: el castellano «muere DEL TODO» |

Tres decisiones del owner, tomadas el 2026-09-15 a la vista de las mediciones:

- **El lint cubre todo el repo**, no solo el alcance de CI: lo que vive fuera de los paquetes
  queda sin verificar si no se nombra en `kit.conf`, que es la regla que ese fichero ya escribe
  para la app.
- **Los imports apuntan al checkout de SPM** (`Packages/Platform/.build/checkouts/…`): están dentro
  del repo —sin diálogo de aprobación— y siguen la versión que el proyecto resuelve. El coste,
  dicho: en un clon limpio no existen hasta `swift package resolve`, y la documentación de Claude
  Code no dice qué hace con un import que no encuentra.
- **`.claude` se excluye en `.swiftlint.yml`** (añadida al empezar a implementar). Al medir la línea
  base salieron **60** violaciones, no 20: las 20 del repo más 20 por cada uno de los dos worktrees
  abiertos en `.claude/worktrees/`. Nombrando las rutas con Swift trackeado (`App AppTests
  AppSnapshotTests AppUITests Packages`) salen exactamente las 20. Se prefiere arreglar el
  `excluded`, que es la causa, a nombrar rutas en `kit.conf`, que dejaría sin lintar cualquier
  directorio nuevo hasta añadirlo.

Ningún cambio de comportamiento de la app. No es **BREAKING**.

## Capabilities

### New Capabilities

Ninguna.

### Modified Capabilities

Ninguna. El cambio no toca comportamiento del producto: el contrato de verificación vive en
`kit.conf` y el contexto del agente en `CLAUDE.md`. Lleva `skip_specs: true`.

## Fuera de alcance

- **swift-format.** `swift format lint --strict` da 78 avisos en `Packages/Features` y 0 en
  `Packages/Platform` (medido el 2026-09-15 con la orden de CI). Ni se corrigen ni entran en
  `kit.conf`: el paso de CI que los mira seguirá fallando.
- **`Scripts/check-showcase.sh`.** Falla por 2 citas rotas del README (`LoginLogic` y
  `any CameraCapturing`, medido el 2026-09-15). CI seguirá en rojo por este motivo también.
- **Cambiar reglas o umbrales de `.swiftlint.yml`**, y el workflow de CI. El `excluded` sí se toca,
  y solo para añadir `.claude`.
- **Otros documentos de los kits:** ni el `Testing.md` de CoreNetworking ni el resto de artículos
  DocC. Solo los tres nombrados.
- **Copiar los documentos al repo.**
- **El texto que inyecta el hook del kit** («rutas con `/kit-doc`»): es del kit.
- **Los worktrees de `.claude/worktrees/`:** se excluyen del lint, no se tocan.

## Criterios de aceptación

- [x] `swiftlint lint --strict --quiet` desde la raíz sale con código 0 y sin salida.
- [x] `.swiftlint.yml` tiene `.claude` en `excluded`, y ninguna regla ni umbral cambia: su diff es
      una sola línea añadida. Con un worktree abierto en `.claude/worktrees/`, la orden del paso no
      informa nada de `.claude/`.
- [x] `kit.conf` tiene un paso `SwiftLint · --strict` con esa orden, antes de los builds, y
      `/kit-verifica` lo muestra en verde.
- [x] Con una violación reintroducida a propósito, la orden de ese paso sale con código distinto
      de 0. Medido una vez y deshecho.
- [x] El número de `swiftlint:disable` en el repo no cambia: sigue siendo 1
      (`NetworkingWiring.swift:25`).
- [x] `CLAUDE.md` contiene los tres `@` con las rutas de arriba, fuera de bloques de código, y la
      frase de precedencia a favor del `AGENTS.md` del proyecto.
- [x] En una sesión nueva, `/context` lista los tres ficheros bajo «Memory files». Lo comprueba el
      owner a mano y queda anotado en `tasks.md`.
- [x] Los cuerpos JSON de `OfflineFixtures` producen los mismos bytes antes y después de partir sus
      líneas. Comprobado con un script de un solo uso.
- [x] Ningún PNG de `AppSnapshotTests/__Snapshots__/` cambia: no se regraba ninguna referencia.
- [x] `AppUITests/SettingsUITests` pasa una vez con
      `xcodebuild test -only-testing:AppUITests/SettingsUITests` (fuera de la firma, por
      `kit.conf`).
- [x] `/kit-verifica` en verde.

## Impact

| Fichero | Qué cambia |
|---|---|
| `CLAUDE.md` | tres `@` y la frase de precedencia y procedencia |
| `kit.conf` | el paso `SwiftLint · --strict` |
| `.swiftlint.yml` | `.claude` en `excluded` |
| los diez ficheros de la tabla de arriba | la corrección de su violación, sin cambiar lo que hacen |

Sin cambios: las reglas y umbrales de `.swiftlint.yml`, `.github/workflows/ci.yml`, el `AGENTS.md`
del proyecto y las specs.
