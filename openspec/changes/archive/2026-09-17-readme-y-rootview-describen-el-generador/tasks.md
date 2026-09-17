## 1. Condiciones previas (si alguna falla, se para sin escribir nada)

- [x] 1.1 Comprobar que `huecos-del-generador-en-el-repo` está archivado en esta rama y que su guía
      ya está en `AGENTS.md`:
      - `ls -d openspec/changes/archive/*-huecos-del-generador-en-el-repo` lista un directorio;
      - `grep -n 'siempre imprime' AGENTS.md` sale vacío;
      - `grep -n '^## Si vas a añadir una feature nueva$' AGENTS.md` da exactamente una línea.

      Si alguna falla, no se sigue: se avisa al owner (ver `design.md`, «Se aplica sobre
      `huecos-del-generador-en-el-repo` archivado»). Verificación: las tres salidas, anotadas en esta
      tarea.
      **Hecho**: `openspec/changes/archive/2026-09-17-huecos-del-generador-en-el-repo` existe;
      `grep -n 'siempre imprime' AGENTS.md` sale vacío; y
      `grep -n '^## Si vas a añadir una feature nueva$' AGENTS.md` da una sola línea, la 97.
- [x] 1.2 Comprobar que AppFoundation está en 1.4.2 en los dos `Packages/*/Package.resolved`, con
      `grep -A7 '"appfoundation"' Packages/*/Package.resolved | grep '"version"'`, que tiene que dar
      dos líneas con `"1.4.2"`. La versión cambió después de escribirse este acuerdo, así que la
      medición se repitió y la renegociación está escrita al final de `proposal.md`: el
      comportamiento que este cambio describe es el mismo, y lo que cambia es la versión que los dos
      textos nombran. Verificación: las dos versiones, anotadas.
      **Hecho, y la versión había cambiado**: los dos `Package.resolved` dan `"1.4.2"`, no
      `"1.4.1"`. Así que se hizo lo que esta tarea manda: releído
      `Plugins/GenerateFeature/MultiMode.swift` en el checkout `1da0bdb` (tag `1.4.2`) y repetida
      la medición en un worktree desechable con `GuiaPrueba --api --local`. El comportamiento que
      este cambio describe es el mismo; lo que cambia es la versión que nombran los dos textos. La
      renegociación está escrita al final de `proposal.md`.
- [x] 1.3 Línea base, antes de tocar nada:
      - `grep -n 'struct RootView' App/RootView.swift` da `28`;
      - `swift format lint --strict --configuration .swift-format App/RootView.swift` sale con 0;
      - `Scripts/check-showcase.sh` sale con 0.

      Verificación: las tres salidas, anotadas.
      **Hecho**: `grep -n 'struct RootView' App/RootView.swift` → `28`;
      `swift format lint --strict --configuration .swift-format App/RootView.swift` → 0;
      `Scripts/check-showcase.sh` → 0.

## 2. `README.md`

- [x] 2.1 Reescribir el párrafo de «El kit, usado de verdad» que sigue al bloque de órdenes (el que
      empieza por «`generate-feature` en modo multi»), con el contenido de `proposal.md`, «What
      Changes». Solo cambia lo que el generador registra: la frase de las features movidas a mano
      desde `AppStarterKit/` se queda igual. Verificación: en ese párrafo aparecen `1.4.2`,
      `archinit:features-begin/end`, `archinit:products-begin/end`, `// archinit:imports`,
      `// archinit:modules`, `// archinit:destinations`, `# archinit:products`, `App/RootView.swift`,
      `project.yml` y `AGENTS.md`. Además, `grep -n 'App/AppModule.swift`/`App/AppRoute.swift`' README.md`
      sale vacío.
      **Hecho, en la ronda 2**: el párrafo nombra `1.4.2` y las diez cosas que pide el criterio,
      **cada marker con el fichero que edita**, que es la mitad del criterio que la ronda 1 no
      cumplió: el módulo iba con su marker pero sin `App/AppModule.swift`
      —`archinit:features-begin/end`, `archinit:products-begin/end`, `// archinit:imports`,
      `// archinit:modules`, `// archinit:destinations`, `# archinit:products`,
      `App/RootView.swift`, `project.yml` y `AGENTS.md`—, dice que el `case` de la ruta no lo
      añade aquí y remite a la sección de la guía. El par `App/AppModule.swift`/`App/AppRoute.swift`
      ya no aparece en el README. La frase de los seis features movidos a mano desde
      `AppStarterKit/` queda intacta.
- [x] 2.2 Reescribir el párrafo de «Añadir una feature nueva» que sigue al bloque de
      `generate-feature`. Remite a `AGENTS.md` § «Si vas a añadir una feature nueva» para los pasos
      manuales, sin listarlos, y conserva la frase de `swift package archlint` y R13. Verificación:
      `sed -n '/^### Añadir una feature nueva/,/^### Reutilizar/p' README.md | grep -nE 'imprime el comando|si no hay marker|el destino en'`
      sale vacío. Y la misma sección contiene `AGENTS.md`, `Si vas a añadir una feature nueva` y
      `R13`.
      **Hecho**: en esa sección no queda ni «imprime el comando», ni «si no hay marker», ni «el
      destino en». Remite a `AGENTS.md` § «Si vas a añadir una feature nueva» y conserva la frase
      de `swift package archlint` y R13.

## 3. Comentario de `struct RootView`

- [x] 3.1 Sustituir el párrafo del generador del comentario de `struct RootView` (líneas 23-27) por
      otro de cinco líneas `///`, en inglés, con cada línea de 120 columnas como máximo. Tiene que
      decir:
      - que `generate-feature` (modo multi, AppFoundation 1.4.2) edita este fichero en
        `// archinit:imports` y `// archinit:destinations`;
      - que el `case` de `AppRoute` se añade a mano en `Domain`, porque el generador no lo encuentra;
      - que los pasos manuales están en `AGENTS.md` § «Si vas a añadir una feature nueva».

      Verificación:
      - `grep -n 'struct RootView' App/RootView.swift` sigue dando `28`;
      - `grep -nE 'never edits this file|always prints' App/RootView.swift` sale vacío;
      - `git diff -U0 App/RootView.swift | grep -E '^[+-]' | grep -vE '^(\+\+\+|---)' | grep -vE '^[+-][[:space:]]*///'`
        sale vacío;
      - `sed -n 19,27p App/RootView.swift | awk 'length > 120'` sale vacío;
      - la orden de swift-format de la 1.3 sigue saliendo con 0.
      **Hecho**: cinco líneas `///` en inglés, las mismas que había. `struct RootView` sigue en
      la línea 28; `never edits this file` y `always prints` ya no aparecen; el
      `git diff -U0 App/RootView.swift` filtrado no deja ni una línea que no empiece por `///`;
      ninguna línea de 19-27 pasa de 120 columnas; y la orden de swift-format de la 1.3 sigue
      saliendo con 0.

## 4. Cierre

- [x] 4.1 Comprobar el alcance y las citas del README. Verificación: `git diff --stat` solo enseña
      `README.md` y `App/RootView.swift`, `Scripts/check-showcase.sh` sale con 0, y
      `grep -n '1\.4\.2' README.md App/RootView.swift AGENTS.md` encuentra los tres ficheros.
      **Hecho**: medido antes de stagear, `git diff --stat` enseñaba solo `App/RootView.swift`
      y `README.md`. Con todo staged hay que mirarlo con `git diff --cached --stat`, que además
      lista los cuatro ficheros de este directorio: fuera de ellos no hay nada más.
      `Scripts/check-showcase.sh` → 0 («50 citas verificadas, 0 fallos»). Y `grep -c '1\.4\.2'`
      encuentra una ocurrencia en cada uno de los tres ficheros —README, comentario y guía—, que
      es el invariante que pedía `design.md`. La del tercero viene de `def4010`, no de este
      cambio: `AGENTS.md` no está en el diff.
- [x] 4.2 `/kit-verifica` en verde. Si este worktree no tiene `AppStarter.xcodeproj`, antes se
      ejecuta `Scripts/bootstrap.sh`. Verificación: el resultado de la firma, anotado.
      **Hecho**: los nueve pasos en verde, incluido `App · build + AppTests + AppSnapshotTests`,
      sobre el árbol y el índice de este cambio. No hizo falta `Scripts/bootstrap.sh`: el
      `.xcodeproj` ya estaba. Firmado otra vez tras anotar esta tarea, porque la anotación cambia
      el índice y tira la firma anterior.

## Rondas de aceptación

- **Ronda 1 — DEVUELTO** (juez, 2026-09-17). Un criterio incumplido: el párrafo de «El kit, usado
  de verdad» nombraba los seis markers, pero el del módulo iba sin el fichero que edita, cuando
  `proposal.md` pedía «el módulo **en `App/AppModule.swift`**». En un cambio que existe porque el
  README atribuía cosas al fichero equivocado, es el defecto que menos se puede dejar pasar.
  Corregido en `README.md`. El juez dio por legítima la renegociación a 1.4.2 —comprobó contra
  `MultiMode.swift` del checkout `1da0bdb` que el comportamiento descrito es el mismo— y encontró
  dos hechos de la 1.4.1 que esa renegociación no había corregido: el `grep` de ejemplo de
  `design.md` y la mitad de un bullet de «Fuera de alcance» sobre la coma de la lista de módulos.
  Los dos, corregidos aquí. También señaló dos anotaciones mías que describían un estado anterior
  al staging: reescritas.
- **Ronda 2 — ACEPTADO** (juez, 2026-09-17). Verificó los nueve criterios con evidencia de hoy y
  comparó contra el texto de la ronda 1, recuperado de los blobs colgantes del índice
  (`git fsck --dangling`). Dos observaciones que no eran motivo de devolución, y lo que se hizo
  con ellas:
  - el párrafo de «Añadir una feature nueva» había quedado con un salto de línea desigual al
    reescribirlo (una línea de 34 columnas). Reflujado, sin tocar la frase de `archlint`/R13;
  - dos criterios de `proposal.md` dicen `git diff -U0 …` y `git diff --stat`, que con todo
    staged devuelven vacío. Se comprueban con `--cached` y pasan. Queda escrito aquí, no
    corregido en los criterios: se redactaron así y así se juzgaron; si este acuerdo se reutiliza
    como plantilla, ahí van con `--cached`.
