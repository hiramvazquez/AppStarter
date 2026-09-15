## 1. La línea base

- [x] 1.1 Medir antes de tocar nada, sobre `94deb9c` (la base renegociada), y guardar las salidas en
      el scratchpad:
      - `git log -1 --format=%h` da `94deb9c`;
      - en `Packages/Features`, `swift format lint --strict --configuration ../../.swift-format
        --recursive Sources Tests 2>&1 | wc -l` tiene que dar `84`;
      - la misma orden en `Packages/Platform` tiene que dar `0`;
      - desde la raíz, `swiftlint lint --strict --quiet` sale con código 0 y sin salida. Es la
        línea base de la 3.3;
      - `git status --short` solo enseña este cambio de `openspec/`.

      Si algún número no sale, se revisa el acuerdo antes de seguir.
      Verificación: los cinco resultados, anotados en esta tarea.

      *Medido el 2026-09-15 14:17:* HEAD `94deb9c`; Features `84`; Platform `0`; SwiftLint código
      0 y 0 líneas; `git status --short` solo enseña
      `?? openspec/changes/features-pasa-swift-format-estricto/`.
- [x] 1.2 Copiar `Packages/Features/Sources` y `Packages/Features/Tests` al scratchpad como
      `before/`, para la sección 3. Verificación: `diff -rq` entre la copia y el repo sale vacío.

      *Hecho:* `diff -rq` vacío en `Sources` y en `Tests`.

## 2. Formatear

- [x] 2.1 En `Packages/Features`: `swift format format --in-place --configuration ../../.swift-format
      --recursive Sources Tests`, una pasada y sin retoques a mano. Verificación: sale con código 0,
      y `git diff --name-only` lista exactamente los 14 ficheros de la tabla del proposal.

      *Hecho con swift-format 6.3.3:* código 0. `git diff --name-only` coincide con la tabla
      (`diff` vacío contra la lista), y `git diff --shortstat` da 14 ficheros, 90 inserciones y
      67 borrados.
- [x] 2.2 La orden de lint de CI sale con código 0 y sin salida en `Packages/Features` y en
      `Packages/Platform`. Verificación: los dos códigos de salida, anotados.

      *Medido:* Features código 0 y 0 líneas; Platform código 0 y 0 líneas.
- [x] 2.3 Idempotencia: la orden de la 2.1 otra vez. Verificación: `git diff | shasum` da lo mismo
      antes y después de la segunda pasada.

      *Medido:* `137b2d15567f08cb20e3c94a15a93df896633758` antes y después.
- [x] 2.4 La versión de CI. En el scratchpad, fuera del repo:
      - clonar `swiftlang/swift-format` en el tag `swift-6.2.4-RELEASE`;
      - fijar su dependencia de swift-syntax al commit del mismo tag;
      - `swift build -c release --product swift-format`.

      Con ese binario, la orden de lint de CI sale con código 0 y sin salida en `Packages/Features`
      y en `Packages/Platform`. Y formatear otra copia de `before/` da el mismo resultado que el
      repo: `diff -r` vacío. Si algo no coincide, se para y se renegocia el acuerdo (`design.md`).
      Verificación: el `--version` del binario, los dos códigos de salida y el `diff -r`, anotados.

      *Medido:* swift-format `63687c7` (tag `swift-6.2.4-RELEASE`) con swift-syntax `5a87516` (el
      commit del mismo tag). `--version` da `6.2.4`. Features: código 0 y 0 líneas; Platform: código
      0 y 0 líneas. `diff -r` entre `before/` formateado con la 6.2.4 y el repo: vacío.

## 3. Que el diff es solo formato

- [x] 3.1 Un script de un solo uso en el scratchpad compara `before/` con el repo, fichero a fichero:
      - (a) sin espacios, sin la coma final antes de `]` o `)` y con los `import` ordenados, el
        texto es idéntico;
      - (b) cada literal `"""` da el mismo SHA-256, calculado con la regla de Swift: a cada línea
        se le quita la sangría del `"""` de cierre.

      Verificación: 14 ficheros `OK` y 3 literales con el mismo hash, anotados.

      *Medido:* `ficheros OK: 14/14 · literales iguales: 3/3`. Los hashes, abreviados:
      - `CartServiceTests.swift`: `e464dae2942e`;
      - `CartUpdateServiceTests.swift`: `74a96352b507` y `48df5dc323ee`.
- [x] 3.2 Leer el `git diff` entero. Verificación: ninguna línea cambia código, el texto de un
      comentario ni el de un literal. Solo cambian sangría, espacios, saltos de línea, comas finales
      y el orden de los `import`. Anotado con el número de líneas cambiadas.

      *Leído entero:* 157 líneas cambiadas (90 inserciones y 67 borrados) en 14 ficheros.
      - Sangría: el comentario del closure de `performLoad` en los dos ViewModels.
      - Espacios: dos antes de un `//` a final de línea.
      - Saltos de línea: `#expect(…)`, `Data("""…""".utf8)` y un `.init(…)`. En
        `CartUpdateServiceTests.swift`, el `#expect` envuelve el array que ya partió `lint-estricto…`.
      - Comas finales: 5.
      - `import Foundation` antes de `import Networking`: 4 tests.
      - La línea en blanco final de `ProductsViewModelTests.swift`.

      Ningún token cambia fuera de esto.
- [x] 3.3 SwiftLint no empeora: `swiftlint lint --strict --quiet` desde la raíz sigue saliendo con
      código 0 y sin salida, como en la línea base de la 1.1. Verificación: el código de salida y
      el número de líneas, anotados.

      *Medido:* código 0 y 0 líneas.

## 4. Coordinación

- [x] 4.1 Antes del cierre, mirar en qué punto está `lint-estricto-y-reglas-de-los-kits-en-contexto`
      en el checkout principal: `git status --short` y su `tasks.md`. Si ya tocó alguno de los tres
      ficheros compartidos, se para y se sigue `design.md` («El orden con `lint-estricto…`»).
      Verificación: el estado, anotado con la fecha.

      *Mirado el 2026-09-15 13:57:* `lint-estricto…` lleva 20 de 21 tareas, sin commitear, y
      tiene modificados los tres ficheros compartidos. **Parado** hasta que el owner decida qué
      cambio entra primero.

      *Decisión del owner, 2026-09-15: entra primero `lint-estricto…`.* La primera pasada de 1.1 a
      3.3 se hizo sobre `dfc20bc` y se descarta para rehacerla. Dio:
      - 78 avisos antes y 0 después, en los 14 ficheros de la tabla;
      - el mismo `git diff | shasum` en la segunda pasada (`ef0442f2…`);
      - con la 6.2.4, 0 avisos en los dos paquetes y el mismo árbol;
      - 14/14 ficheros y 3/3 literales iguales, y 149 líneas cambiadas;
      - SwiftLint de 20 a 19, sin parejas nuevas.

      *Renegociado el 2026-09-15 14:15 (owner):* al retomar, `lint-estricto…` estaba commiteado como
      `94deb9c`, pero no en `main`. Se parte de ese commit (proposal, «Renegociado…»):
      1. Descartar los 14 ficheros formateados, tras comprobar que su diff es el de la primera
         pasada, y traer esta rama a `94deb9c` con `git merge --ff-only`.
      2. Actualizar las cifras por escrito en `proposal.md`, en la 1.1 y en la 3.3: 84 avisos, los
         mismos 14 ficheros y SwiftLint en 0.
      3. Repetir de 1.1 a 3.3 sobre `94deb9c`.
      4. Marcar esta tarea y seguir.
- [x] 4.2 Antes del cierre, anotar si `main` contiene ya `94deb9c`, con
      `git merge-base --is-ancestor 94deb9c main`. Si no lo contiene, la regla de fusión del proposal
      sigue en pie y se recuerda en el cierre. Verificación: la salida, anotada con la fecha.

      *Mirado el 2026-09-15 14:18:* `main` y `origin/main` están en `8231924` y **no** contienen
      `94deb9c`.
      - `git merge-base --is-ancestor` sale con 1, y `git cherry` no encuentra un parche
        equivalente.
      - `8231924` fusiona otra rama, que trae `README.md` y una línea de
        `Packages/Features/Package.swift`, sin tocar `Sources` ni `Tests`.
      - La regla de fusión sigue en pie, precisada a `Sources` y `Tests` (proposal, «Renegociado…»).

## 5. Cierre

- [x] 5.1 Repasar uno a uno los criterios de aceptación de `proposal.md` y marcarlos.
      Verificación: ninguna casilla sin marcar sin una nota que diga por qué.

      *Hecho:* los 11 criterios marcados, cada uno con la tarea o la medida que lo prueba.
- [x] 5.2 `/kit-verifica` en verde y, después, `git status --short AppSnapshotTests/__Snapshots__`
      vacío. Verificación: el resultado de la firma y la salida vacía, anotados.

      *Primera corrida (14:22), en rojo, con dos pasos.*
      - `App`: `'AppStarter.xcodeproj' does not exist`. Este worktree no lo había generado nunca;
        se genera con `Scripts/bootstrap.sh`, y `.gitignore` lo ignora (`*.xcodeproj/`).
      - `Features · tests`: `error: fatalError` en plena compilación, en el paso [85/98].
        Repetido a mano, `swift test` sale con 0: 217 tests en 39 suites, sin fallos. No se
        volvió a ver, y la causa no está identificada.

      *Segunda corrida (2026-09-15 14:24), en verde.* Salen bien los siete pasos: SwiftLint, build y
      tests de Platform y Features, App con AppTests y AppSnapshotTests, y lógica repetida (ningún
      grupo nuevo; 2 preexistentes). `--comprueba` dice «firma válida para este árbol», con diff
      `c1c9a3e53096…`. `git status --short AppSnapshotTests/__Snapshots__` sale vacío.
