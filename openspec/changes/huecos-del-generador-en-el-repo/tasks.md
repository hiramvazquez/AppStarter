## 1. Línea base

- [x] 1.1 Medir, antes de tocar nada —subida de versión incluida— y desde la raíz:
      - `swiftlint lint --strict --no-cache 2>&1 | tail -1` tiene que decir `0 violations` en `176
        files`;
      - las dos órdenes de swift-format de CI, cada una desde `Packages/<paquete>`, tienen que salir
        con código 0;
      - `grep -n 'Package.swift' .swiftlint.yml` tiene que dar una sola entrada en `excluded`, sin
        glob.

      Si algo no coincide, se revisa el acuerdo antes de seguir. Verificación: las tres salidas,
      anotadas en esta tarea.
      **Hecho** (2026-09-17, antes de tocar nada): `swiftlint lint --strict --no-cache` →
      `Done linting! Found 0 violations, 0 serious in 176 files.`; las dos órdenes de
      swift-format, `exit=0` las dos; `.swiftlint.yml:67` → `  - Package.swift`, una sola
      entrada y sin glob. Coincide con lo que declara el acuerdo, así que se sigue.

## 2. Subida a AppFoundation 1.4.2

- [x] 2.1 En `project.yml`, `Packages/Platform/Package.swift` y `Packages/Features/Package.swift`,
      AppFoundation pasa de `1.4.1` a `1.4.2`. CoreNetworking no se toca. Verificación:
      `grep -n "from:" project.yml Packages/Platform/Package.swift Packages/Features/Package.swift`
      enseña `1.4.2` para AppFoundation y `1.3.1` para CoreNetworking en los tres.
      **Hecho**: los tres declaran AppFoundation `1.4.2` y CoreNetworking `1.3.1`. El primer
      intento corrompió la línea de `Packages/Platform/Package.swift` con una sintaxis de `sed`
      de GNU (`\g<1>`) que BSD no entiende y no falla; se restauró con `git checkout --` y se
      rehizo.
- [x] 2.2 Resolver en los dos paquetes (`swift package resolve`, que no mueve dependencias que no
      han cambiado de requisito) y en el proyecto (`xcodegen generate` +
      `xcodebuild -resolvePackageDependencies`). Verificación: los tres `Package.resolved` fijan
      `appfoundation 1.4.2`, y `git diff Packages/*/Package.resolved` solo cambia la entrada de
      `appfoundation` (versión y revisión).
      **Hecho**: `swift package resolve` en los dos paquetes, `xcodegen generate` y
      `xcodebuild -resolvePackageDependencies`. Los tres `Package.resolved` fijan
      `appfoundation 1.4.2` en la revisión `1da0bdb`, y en los dos versionados no cambia
      ninguna otra entrada (solo su `originHash`). Esa revisión es la del tag `1.4.2`, que
      sigue apuntando al mismo commit después de que `main` del repo publicado se reescribiera
      ese mismo día.

## 3. `kit.conf` y `.swiftlint.yml`

- [x] 3.1 `kit.conf`: añadir `paso "Platform · swift-format"` y `paso "Features · swift-format"`,
      cada uno con
      `bash -c 'cd Packages/<paquete> && swift format lint --strict --configuration ../../.swift-format --recursive Sources Tests'`,
      justo después de `SwiftLint · --strict`. Llevan un comentario breve, sin cifras: la orden y
      el alcance son los de CI a propósito, y ampliarlo es otro cambio. Verificación:
      `bash -c 'paso(){ echo "$1"; }; source kit.conf; verificaciones' | head -3` imprime
      `SwiftLint · --strict`, `Platform · swift-format` y `Features · swift-format`, en ese orden.
      Y `grep -c 'swift format lint --strict --configuration ../../.swift-format --recursive Sources Tests' kit.conf .github/workflows/ci.yml`
      da `2` en `kit.conf` y `1` en `ci.yml`.
      **Hecho**: `bash -c 'paso(){ echo "$1"; }; source kit.conf; verificaciones' | head -3`
      imprime `SwiftLint · --strict`, `Platform · swift-format` y `Features · swift-format`, en
      ese orden. El `grep -c` de la orden da `kit.conf:2` y `.github/workflows/ci.yml:1`.
- [x] 3.2 Comprobar que el paso muerde: sangrar mal una línea de un fichero de
      `Packages/Features/Sources` y ejecutar la orden del paso `Features · swift-format`. Luego
      restaurar el fichero con `git checkout -- <fichero>` y volver a ejecutarla. Verificación: el
      primer código de salida es distinto de 0, el segundo es 0 y `git status --short Packages`
      solo enseña los manifiestos y `Package.resolved` de la tarea 2. Los dos códigos, anotados.
      **Hecho**: con `import Foundation` sangrado ocho espacios en
      `Packages/Features/Sources/CartFeature/CartCopy.swift`, la orden del paso sale con **1**;
      restaurado el fichero con `git checkout --`, sale con **0**. `git status --short Packages`
      solo enseña los cuatro ficheros de la tarea 2 (los dos manifiestos y los dos
      `Package.resolved`).
- [x] 3.3 `.swiftlint.yml`: la entrada `- Package.swift` de `excluded` pasa a `- "**/Package.swift"`,
      con un comentario encima que diga por qué:
      - la longitud de un manifiesto generado crece con el número de features;
      - `Package.swift` a secas solo encajaba en la raíz, que en modo multi no tiene manifiesto.

      Verificación: `git diff .swiftlint.yml` solo toca esa entrada y su comentario. Y
      `swiftlint lint --strict --no-cache 2>&1 | tail -1` dice `0 violations` en `174 files`.
      **Hecho**: `git diff .swiftlint.yml` solo toca esa entrada y el comentario nuevo, sin
      cambiar ninguna regla ni umbral. `swiftlint lint --strict --no-cache` →
      `Found 0 violations, 0 serious in 174 files`: dos ficheros menos, los dos manifiestos.
- [x] 3.4 Comprobar la exclusión en una copia del scratchpad, con el `.swiftlint.yml` nuevo, un
      `Packages/Features/Package.swift` de más de 400 líneas y un
      `Packages/Features/Sources/X/Long.swift` de más de 400. Verificación: `swiftlint lint --strict
      --no-cache` informa `file_length` de `Long.swift` y no del manifiesto. La salida, anotada.
      **Hecho**: copia en el scratchpad con el `.swiftlint.yml` nuevo,
      `Packages/Features/Package.swift` a 476 líneas y `Packages/Features/Sources/X/Long.swift`
      a 450. Salida: `Long.swift:450:1: error: File Length Violation: File should contain 400
      lines or less … currently contains 450 (file_length)` —la cifra que imprime la regla es de
      líneas de código, no del fichero, por `ignore_comment_only_lines`— y
      `Found 1 violation, 1 serious in 1 file`. El manifiesto no se lintea.

## 4. La guía de `AGENTS.md`

- [x] 4.1 Reescribir el párrafo de «Si vas a añadir una feature nueva» que sigue al bloque de
      `generate-feature`. Tiene que decir:
      - qué registra el generador en modo multi: el target y su test target en `Package.swift`, el
        `import` en `App/AppModule.swift` y `App/RootView.swift`, el módulo, el destino y el
        producto en `project.yml`;
      - que se comprobó con AppFoundation 1.4.2;
      - los dos pasos manuales, numerados y en el orden de `proposal.md`: el `case` en
        `Packages/Platform/Sources/Domain/AppRoute.swift` —avisando de que el generador imprime
        `App/AppRoute.swift`, que aquí no existe— y `xcodegen generate` / `Scripts/bootstrap.sh`.

      Verificación: `grep -n 'siempre imprime' AGENTS.md` sale vacío; la sección nombra `1.4.2`,
      `Domain/AppRoute.swift` y `xcodegen generate`; y no contiene `Expected ',' separator` ni
      `swift format format`.
      **Hecho**: `grep -n 'siempre imprime' AGENTS.md` sale vacío; la sección nombra `1.4.2`,
      `Packages/Platform/Sources/Domain/AppRoute.swift` y `xcodegen generate`; y
      `grep -c "Expected ',' separator\|swift format format" AGENTS.md` da `0`.
- [x] 4.2 En «Generador y linter», la frase «el resto de pasos manuales (arriba…), imprímelos y
      hazlos tú» pasa a remitir a la sección sin decir que el generador los imprime. Verificación:
      `grep -n 'imprímelos' AGENTS.md` sale vacío.
      **Hecho**: `grep -n 'imprímelos' AGENTS.md` sale vacío. La frase pasa a decir que el
      generador registra la feature en la app y remite a la sección de arriba.

## 5. La guía, seguida al pie de la letra

- [x] 5.1 Crear un worktree desechable en el scratchpad desde `HEAD` y aplicarle el diff sin
      commitear de este (`git diff | git -C <worktree> apply`). Verificación: `git -C <worktree>
      diff --stat` enseña `project.yml`, los dos `Package.swift`, los dos `Package.resolved`,
      `kit.conf`, `.swiftlint.yml` y `AGENTS.md`, y nada más.
      **Hecho**: worktree `prueba/guia-huecos` creado desde `e5fcc64` en el scratchpad, con
      `git diff | git -C <worktree> apply`. `git -C <worktree> diff --stat` enseña los ocho
      ficheros de «Impact» y nada más.
- [x] 5.2 En ese worktree, generar la feature con
      `swift package --allow-writing-to-package-directory generate-feature GuiaPrueba --api --local`
      desde `Packages/Features`, y aplicar los dos pasos tal como los dice la guía nueva, sin nada
      que no esté escrito en ella: ni coma a mano ni formateo. Verificación: la salida del generador
      y el diff de `App/AppModule.swift`, anotados.
      **Hecho**: el generador creó 13 ficheros y registró el target, su test target y el
      producto entre los markers, el `import` en `App/AppModule.swift` y `App/RootView.swift`,
      el módulo, el destino `case .guiaPrueba:` y el producto de `project.yml`. Imprimió un solo
      paso a mano, con la ruta que aquí no existe:
      `App/AppRoute.swift: no existe App/AppRoute.swift — añade 'case guiaPrueba' a mano`.
      El diff de `App/AppModule.swift` es la prueba de que la 1.4.2 arregló la coma:
      `-            CartModule()` → `+            CartModule(),` y
      `+            try GuiaPruebaModule(baseURL: AppModule.apiBaseURL)`, el nuevo último y sin
      coma. Después, los dos pasos de la guía tal cual: `case guiaPrueba` en
      `Packages/Platform/Sources/Domain/AppRoute.swift` y `xcodegen generate`. Ni coma a mano ni
      formateo.
- [x] 5.3 En ese worktree, ejecutar:
      - `swiftlint lint --strict --quiet` desde la raíz;
      - los dos pasos de swift-format de `kit.conf`;
      - `swift build` en `Packages/Features`;
      - el `xcodebuild build-for-testing` del paso de la app de `kit.conf`.

      Verificación: los cuatro salen con código 0, y así queda anotado. Si alguno falla, la guía
      está mal: se corrige la 4.1 y se repiten la 5.2 y la 5.3 en un worktree nuevo.
      **Hecho, las cuatro comprobaciones del criterio con código 0** —la segunda son las dos
      órdenes de swift-format—: `swiftlint lint --strict --quiet` → 0;
      `Platform · swift-format` → 0; `Features · swift-format` → 0; `swift build` en
      `Packages/Features` → 0 (15,24 s); `xcodebuild build-for-testing` de la app → 0 (33 s).
      Los avisos de aislamiento de actor que imprime XCUIElement son preexistentes y no son
      errores. La guía, por tanto, no le deja nada al lector que tenga que descubrir por el
      error.
- [x] 5.4 Borrar el worktree desechable (`git worktree remove --force <worktree>`) y la rama que se
      haya creado. Verificación: `git worktree list` no lo lista, y `git status --short` en este
      árbol solo enseña los ocho ficheros de «Impact» y
      `openspec/changes/huecos-del-generador-en-el-repo/`.
      **Hecho**: `git worktree remove --force` y `git branch -D prueba/guia-huecos`.
      `git worktree list` ya no lo lista —solo quedan este árbol y los dos worktrees de
      `.claude/`— y `git status --short` enseña los ocho ficheros de «Impact» y
      `openspec/changes/huecos-del-generador-en-el-repo/`.

## 6. Cierre

- [x] 6.1 `/kit-revisa` sobre el diff: ¿esto rompe algo?
      **Hecho — GREEN**: «¿esto rompe algo? No». El revisor ejecutó las comprobaciones en vez
      de leerlas: reprodujo la sonda del paso de swift-format (`exit=1` con `[Indentation]`),
      comprobó con `sort -u` que la orden de `kit.conf` y la de `ci.yml` son la misma cadena,
      que el glob nuevo es superconjunto del viejo —los dos ficheros que dejan de linearse son
      los dos manifiestos, con `find` + `comm`—, y contrastó la guía contra
      `MultiMode.swift` del checkout `1da0bdb`: `registerAppWiring:544-565` y
      `registerAppModule:605` hacen lo que la guía dice, `registerAppRoute:632` busca la ruta
      que aquí no existe, y `printMultiNextSteps` **no** imprime el paso de `xcodegen`, que es
      lo que justifica quitar «imprímelos». Además: `makeModules()` es `throws`, así que el
      `try <X>Module(...)` que inserta el generador compila, y el único `switch` exhaustivo
      sobre `AppRoute` es `destination(for:)`, así que el `case` nuevo no rompe nada más.
      De sus cuatro notas opcionales se aplicó **una**, por ser texto de este cambio: el primer
      bullet de la guía separa ahora `archinit:features-begin`/`-end` (target y test target) de
      `archinit:products-begin`/`-end` (producto), y nombra `// archinit:imports`. Las otras
      tres quedan abajo, en «Hallazgos fuera de alcance».
- [x] 6.2 `/kit-acepta`: el cambio toca más de cinco ficheros y el alcance se movió antes de
      implementar (la subida a 1.4.2).
      **Hecho — ACEPTADO**: el juez midió por su cuenta los diez criterios, sin fiarse de lo
      anotado aquí, incluida la guía seguida entera en un worktree propio desde cero. Le
      salieron los mismos números: 176 → 174 ficheros, `exit` 1/0 en la sonda, ~14 s de
      `swift build`, 33 s de `build-for-testing`. Confirmó que el diff son los ocho ficheros de
      «Impact» más este directorio, que `ci.yml`, `.swift-format`, `App/`, `README.md` y `docs/`
      están intactos, y que el informe de verificación estaba ligado a la huella del árbol y no
      era rancio. Dos notas de redacción suyas, aplicadas: la 5.3 dice «las cuatro
      comprobaciones del criterio» —enumeraba cinco órdenes para cuatro bullets— y la 3.4
      aclara que la cifra de `file_length` es de líneas de código, por
      `ignore_comment_only_lines`.
- [x] 6.3 `/kit-verifica` en verde, con los pasos `Platform · swift-format` y
      `Features · swift-format` en el informe. Si este árbol no tiene `AppStarter.xcodeproj`,
      antes se ejecuta `Scripts/bootstrap.sh`. Verificación: el resultado de la firma, anotado.
      **Hecho**: `/kit-verifica` en verde, con `Platform · swift-format` y
      `Features · swift-format` en el informe, entre `SwiftLint · --strict` y
      `Platform · build`. No hizo falta `Scripts/bootstrap.sh`: este árbol ya tenía
      `AppStarter.xcodeproj`, regenerado en la tarea 2.2. Los nueve pasos en verde, incluido
      `App · build + AppTests + AppSnapshotTests`. Firmado de nuevo después de aplicar las
      correcciones del revisor y del juez, porque cada edición invalida la firma anterior: la
      que lleva el commit es la del árbol final.

## Hallazgos fuera de alcance

Del revisor, y no se tocan aquí porque este cambio no los cubre. Quedan escritos para que el
owner decida, no como deuda anónima:

- **`README.md:191-193` y `README.md:448` describen un CI que no existe**: dicen que se pasa
  `swift format lint` sobre `Packages`, `App`, `AppTests` y `AppUITests`, y esa orden hoy falla
  (`proposal.md` mide 9 avisos en `App`, 1 en `AppSnapshotTests` y 4 en el manifiesto de
  Features). Es preexistente, pero ahora choca con un contrato escrito en `kit.conf`.
- **`Templates/swiftlint.yml` de AppFoundation 1.4.2 sigue instalando `- Package.swift` sin
  glob**: un `swift package archinit` futuro revertiría en silencio la entrada de
  `.swiftlint.yml` que este cambio corrige. Nada de este repo ejecuta `archinit` solo. Va a
  AppFoundation, como los otros defectos del generador.
- **`AppTests/CompositionRootTests.swift:38-51` replica a mano la lista de módulos**: una
  feature nueva compila y deja todo verde, pero se queda fuera del smoke test del composition
  root. La guía no lo menciona.
