## 1. La línea base y el paso

- [x] 1.1 Medir la línea base antes de tocar nada. `swiftlint lint --strict --quiet 2>&1 | grep -c
      ": error:"` desde la raíz tiene que dar `20`, y
      `grep -rn "swiftlint:disable" --include='*.swift' App AppTests AppSnapshotTests AppUITests Packages/*/Sources Packages/*/Tests | wc -l`
      tiene que dar `1`. Si no salen 20 y 1, se revisa el acuerdo antes de seguir.
      Verificación: los dos números, anotados en esta tarea.

      > Medido el 2026-09-15 al empezar: **60** y `1`. No salieron 20, así que se paró y se revisó
      > el acuerdo. Las 40 de más eran de los dos worktrees abiertos en `.claude/worktrees/`
      > (`keen-moser-2e59f0` y `xenodochial-khayyam-46ffe3`), que son copias completas del repo con
      > las mismas 20 cada una. Con solo las rutas que tienen Swift trackeado (`App AppTests
      > AppSnapshotTests AppUITests Packages`) salen exactamente 20, y ninguna de `.claude/`. El
      > owner decidió excluir `.claude` en `.swiftlint.yml`: nace la 1.2, el proposal y el design
      > quedan enmendados, y el paso de `kit.conf` pasa a ser la 1.3.
- [x] 1.2 Añadir `.claude` al `excluded` de `.swiftlint.yml`, sin tocar ninguna regla ni umbral.
      Verificación: `git diff .swiftlint.yml` es una sola línea añadida, y con los worktrees aún
      abiertos `swiftlint lint --strict --quiet 2>&1 | grep -c ": error:"` vuelve a dar `20`, sin
      ninguna ruta de `.claude/`.
- [x] 1.3 Añadir a `kit.conf` `paso "SwiftLint · --strict" swiftlint lint --strict --quiet` como
      PRIMER paso de `verificaciones()`, con un comentario breve: lintea todo el repo porque lo que
      no se nombra queda sin verificar, y SwiftLint pasa a ser dependencia (`brew install
      swiftlint`, como CI). Verificación:
      `bash -c 'paso(){ echo "$1"; }; source kit.conf; verificaciones' | head -1` imprime
      `SwiftLint · --strict`.

## 2. Las violaciones de los paquetes (el alcance de CI)

- [x] 2.1 `Packages/Features/Tests/CartFeatureTests/Mocks/CartMocks.swift`: `setQuantityCalls`
      pasa de tupla a un `struct` con `quantity`, `lineId` y `cart`. Verificación: `swift test
      --filter CartViewModel` en `Packages/Features`, en verde sin tocar `CartViewModelTests`.
- [x] 2.2 `Packages/Features/Tests/CartFeatureTests/Services/CartUpdateServiceTests.swift:94`:
      repartir el array literal en varias líneas. Verificación: `swift test --filter
      CartUpdateServiceTests` en verde.
- [x] 2.3 `Packages/Features/Tests/ProductsFeatureTests/ProductsViewModelTests.swift`: `p` pasa a
      `product` en sus dos sitios (174 y 220). Verificación: `swift test --filter
      ProductsViewModel` en verde.

      > 2.1–2.3: `swift test --filter "CartViewModel|CartUpdateServiceTests|ProductsViewModel"`,
      > 31 tests en 6 suites en verde, sin tocar `CartViewModelTests` (2026-09-15).
- [x] 2.4 `Packages/Features/Sources/ProductsFeature/ProductsViewModel.swift:124`: «DEL TODO» pasa
      a «del todo». Solo el comentario. Verificación: `git diff` de ese fichero es una línea de
      comentario.
- [x] 2.5 El alcance de CI queda limpio. Verificación: `swiftlint lint --strict --quiet --config
      .swiftlint.yml Packages/Platform/Sources Packages/Platform/Tests Packages/Features/Sources
      Packages/Features/Tests` sale con código 0 y sin salida.

## 3. Las violaciones de la app y sus tests

- [x] 3.1 `AppTests/CancellationRecognizerTests.swift`: `r` pasa a `recognizer` en sus cuatro
      sitios. Verificación: `swiftlint lint --strict --quiet AppTests/CancellationRecognizerTests.swift`
      sin salida.
- [x] 3.2 `AppSnapshotTests/GallerySnapshotTests.swift`: un helper privado con
      `guard let … else { preconditionFailure("…") }` sustituye los tres `URL(string:)!`.
      Verificación: `swiftlint lint --strict --quiet` sobre ese fichero, sin salida.
- [x] 3.3 `AppSnapshotTests/UploadsSnapshotTests.swift`: `onePixelPNG` pasa a un `static let`
      inicializado por un closure con `guard let … else { preconditionFailure("…") }`.
      Verificación: `swiftlint` sobre ese fichero, sin salida.

      > 3.1–3.3: los tres ficheros, uno a uno con `--config` absoluto, salen con código 0 y sin
      > salida (2026-09-15). Que sigan compilando y que los snapshots no cambien lo fijan la 5.1 y
      > la 5.4.
- [x] 3.4 `AppSnapshotTests/CartSnapshotTests.swift`: los dos carritos del `StubLogic` pasan a
      `private static let`, y `load` se queda en un `switch` corto. Verificación: `swiftlint`
      sobre ese fichero, sin salida. Que los snapshots siguen verdes sin regrabar lo fija la 5.1.
- [x] 3.5 `App/OfflineFixtures.swift`, las líneas largas (140 y 180), en tres pasos:
      - ANTES de tocarlas, un script `swift` de un solo uso en el scratchpad con los literales de
        `loginBody` y `meBody` copiados tal cual, que imprime el SHA-256 de cada `Data`;
      - partir las dos líneas con la continuación `\` de los literales multilínea;
      - el mismo script con los literales nuevos.

      Verificación: los dos pares de SHA-256 coinciden y quedan anotados en esta tarea.

      > 2026-09-15. Antes y después, idénticos:
      > `loginBody` 221 bytes `a1c359e1dd96ad8d3107722ecbcadb6665bac010264d7b7cbc2f517a0b6a1695`;
      > `meBody` 157 bytes `16cdb21554d5e6d3b41f709d8fe9d75732353d47083bf5793ba7290b133bdb8c`.
      > El script se compiló con `swiftc`: el intérprete de `swift` no enlaza CryptoKit. Los
      > literales del «después» se extrajeron del fichero editado con un script, sin reescribirlos
      > a mano, para que la comparación mida el fichero y no lo que se creía haber escrito.
- [x] 3.6 `App/OfflineFixtures.swift`: `withQuery` sin `!`, con `guard let … else {
      preconditionFailure("…") }`. `makeTransport` registra un `private static let exchanges`
      recorrido en bucle, con los mismos intercambios, en el mismo orden y con sus comentarios.
      Verificación: `swiftlint` sobre ese fichero, sin salida. Que compila lo fija la 5.4.
- [x] 3.7 `AppUITests/SettingsUITests.swift`: el test se parte en helpers privados, uno por
      bloque (tema de marca activado, Diagnostics con el tema de marca, vuelta al tema del kit,
      pinning), llamados en el mismo orden y con las mismas aserciones. Verificación: `swiftlint`
      sobre ese fichero sin salida, y el test pasa UNA vez con
      `xcodebuild test -project AppStarter.xcodeproj -scheme AppStarter -destination
      "platform=iOS Simulator,name=iPhone 17" -only-testing:AppUITests/SettingsUITests
      CODE_SIGNING_ALLOWED=NO` (fuera de la firma, por `kit.conf`).

      > 2026-09-15: `swiftlint` sin salida sobre el fichero, y la orden de arriba da
      > `SettingsUITests.testBrandThemeAppliesLiveAndPinningTogglesUpdateSummary` passed,
      > «Executed 1 test, with 0 failures» (99 s), `** TEST SUCCEEDED **`. Ese mismo `xcodebuild`
      > compiló la app y los cuatro targets de test con todas las correcciones del grupo 3.

## 4. Las reglas de los kits en contexto

- [x] 4.1 `CLAUDE.md`: después de `@AGENTS.md`, la frase de precedencia (gana el `AGENTS.md` del
      proyecto), la de procedencia (`cd Packages/Platform && swift package resolve` en un clon
      limpio; se comprueba con `/context`) y las tres líneas `@` con las rutas del proposal, fuera
      de backticks. Verificación: `grep -n "^@" CLAUDE.md` muestra 4 líneas, y `ls` de las tres
      rutas nuevas encuentra los ficheros.
- [x] 4.2 El owner abre una sesión nueva y comprueba con `/context` que los tres ficheros aparecen
      bajo «Memory files». Verificación: anotado en esta tarea, con la fecha.

      > 2026-09-15: el owner lo comprobó con `/context` y salen los tres bajo «Memory files». Ese
      > `/context` corrió en la sesión de la implementación justo después de un `/compact`, que
      > vuelve a cargar `CLAUDE.md`, y el contexto recargado trae el contenido de los tres ficheros.

## 5. Cierre

- [x] 5.1 Estado final. `swiftlint lint --strict --quiet` desde la raíz sale con código 0 y sin
      salida; el recuento de `swiftlint:disable` de la 1.1 sigue dando `1`; y
      `git status --short AppSnapshotTests/__Snapshots__` sale vacío. Verificación: las tres
      salidas, anotadas.

      > 2026-09-15, después de la 5.4: `swiftlint lint --strict --quiet` sale con código 0 y sin
      > salida, con los dos worktrees todavía abiertos; `swiftlint:disable` da `1`; y
      > `git status --short AppSnapshotTests/__Snapshots__` sale vacío.
- [x] 5.2 Mutación del paso: reintroducir un `let r =` en `AppTests/CancellationRecognizerTests.swift`,
      comprobar que `swiftlint lint --strict --quiet` sale con código distinto de 0, y deshacerlo.
      Verificación: el código de salida anotado, y `git diff` de ese fichero igual que antes de la
      mutación.

      > 2026-09-15: con `let r =` en `noSeComeLaCancelacionDeCamara` (marcador contado, 1), la orden
      > sale con código **2** y señala `CancellationRecognizerTests.swift:45:13 … 'r' should be
      > between 3 and 40 characters long (identifier_name)`. Restaurado desde copia: el `git diff`
      > del fichero es idéntico byte a byte al de antes de mutar, y la orden vuelve a salir con 0.
- [x] 5.3 Repasar uno a uno los criterios de aceptación de `proposal.md` y marcarlos.
      Verificación: ninguna casilla sin marcar sin una nota que diga por qué.

      > 10 de 11 marcados. El de `/context` en una sesión nueva queda sin marcar, con su nota: lo
      > comprueba el owner a mano, y es la tarea 4.2.
      >
      > Cerrada la 4.2 (2026-09-15): 11 de 11.
- [x] 5.4 `/kit-verifica` en verde, con el paso `SwiftLint · --strict` en verde.

      > 2026-09-15: `✅ SwiftLint · --strict` es el primer paso, y después Platform build/tests,
      > Features build/tests y App build + AppTests + AppSnapshotTests, todo en verde. Sin lógica
      > repetida en lo que toca el cambio (los 2 grupos preexistentes de siempre). Firmado contra el
      > árbol.
