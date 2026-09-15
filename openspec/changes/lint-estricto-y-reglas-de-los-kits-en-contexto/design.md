## Context

El motivo, las cifras y las dos decisiones del owner están en `proposal.md`. Esto es lo que
condiciona el cómo:

- `verifica.sh` hace `cd` a la raíz del repo (`verifica.sh:31`), y cada `paso "<nombre>" <orden…>`
  de `kit.conf` ejecuta la orden tal cual. Si falla, el informe enseña sus 15 últimas líneas. Corren
  todos los pasos: un fallo no para los siguientes.
- `swiftlint lint --strict --quiet` desde la raíz tarda 0,25 s, con y sin caché (medido el
  2026-09-15). Usa el `.swiftlint.yml` de la raíz, cuyo `excluded` ya deja fuera `.build`,
  `.swiftpm` y `DerivedData`. En local hay SwiftLint 0.65.1; CI instala el de Homebrew sin fijar
  versión.
- Imports de `CLAUDE.md`, según la documentación de memoria de Claude Code:
  - rutas relativas al fichero que importa;
  - dentro del proyecto, sin diálogo de aprobación;
  - se cargan enteros al arrancar y cuentan en contexto en cada sesión;
  - se siguen hasta 4 saltos, y un `@` dentro de código no se importa;
  - qué pasa con un import que no existe NO está documentado;
  - `/context` enseña cuáles se cargaron.
- Los tres documentos suman 208 + 75 + 77 líneas, unos 20 KB. Ninguno tiene un `@` fuera de bloques
  o spans de código (medido), así que no arrastran imports anidados. Hoy son idénticos en
  `Packages/Platform/.build/checkouts`, en `Packages/Features/.build/checkouts` y en `spm-pro`.
- El `build-for-testing` de `kit.conf` compila `AppUITests`, pero la firma no los ejecuta.
- `OfflineFixtures` solo lo ejercitan los UI tests offline: ningún test de la firma fija sus
  cuerpos JSON.
- Precedentes en el repo: `guard let … else { preconditionFailure(…) }` para una URL literal
  (`App/AppModule.swift:33`), y un único `swiftlint:disable:next`, justificado
  (`NetworkingWiring.swift:25`).

## Goals / Non-Goals

**Goals:**

- Que una firma verde de `/kit-verifica` implique SwiftLint `--strict` limpio en todo el repo.
- Que las reglas de los dos kits estén en contexto en cada sesión, sin ir a buscarlas.
- Corregir las 20 violaciones sin cambiar lo que hace ningún código ni regrabar un snapshot.

**Non-Goals:**

- Tocar las reglas o umbrales de `.swiftlint.yml`, el workflow de CI o swift-format. Su `excluded`
  sí se toca, y solo para añadir `.claude` (ver § El paso de SwiftLint).
- Fijar la versión de SwiftLint.

## Decisions

### Los imports, desde el checkout de `Packages/Platform`, con la precedencia escrita

Las tres líneas `@` van justo después de `@AGENTS.md`, cada una en su línea y fuera de backticks
(con backticks no se importan). Van precedidas de dos frases:

- **Precedencia:** donde estos documentos discrepen del `AGENTS.md` del proyecto, gana el del
  proyecto. Es lo que ese `AGENTS.md` ya dice de las guías generales, extendido a los kits.
- **Procedencia:** los ficheros vienen del checkout de SPM y en un clon recién hecho no existen
  hasta `cd Packages/Platform && swift package resolve`. Se comprueba con `/context`.

Checkout de `Platform` y no de `Features`: los dos resuelven ambos kits, pero `/kit-doc` da la raíz
de `Platform`, y basta una. La elección entre checkout, clon `spm-pro` y copia versionada ya la
tomó el owner (proposal).

*Coste asumido:* unas 360 líneas más en contexto en cada sesión, por encima de las 200 que la
documentación recomienda para un `CLAUDE.md`. Lo pide el encargo; si pesa, quitar un import es
borrar una línea.

### El paso de SwiftLint: todo el repo, el primero, con la orden a pelo

```sh
paso "SwiftLint · --strict" swiftlint lint --strict --quiet
```

- **Sin `bash -c` ni `cd`:** `verifica.sh` ya corre en la raíz, y la orden coge de ahí el
  `.swiftlint.yml`.
- **El primero:** cuesta 0,25 s, y así su resultado encabeza el informe.
- **`--quiet`:** si falla, las 15 líneas que enseña el informe son violaciones y no ruido.

*Alternativa descartada:* la orden de CI, paquete a paquete
(`--config ../../.swiftlint.yml Sources Tests`). Deja fuera `App/` y sus tests, en contra de la
decisión del owner.

*Consecuencia, dicha:* SwiftLint pasa a ser una dependencia de la verificación. Sin él instalado,
el paso sale en rojo con «command not found»; no se salta en silencio. Se instala con el mismo
`brew install swiftlint` que usa CI.

*Enmendado el 2026-09-15, al empezar a implementar.* La orden sin rutas confiaba en el `excluded`
de `.swiftlint.yml`, y ese `excluded` no cubría `.claude/`. La línea base de la tarea 1.1 dio 60
violaciones: las 20 del repo y 20 más por cada uno de los dos worktrees que Claude Code tenía
abiertos en `.claude/worktrees/`, que son copias completas del repo. Con el repo limpio, el paso
habría salido en rojo mientras hubiera un worktree abierto.

Decisión del owner: **se añade `.claude` a `excluded`** y la orden se queda sin rutas. Arregla la
causa y conserva que un directorio nuevo con Swift entre solo en el lint.

*Alternativa descartada:* nombrar las rutas en `kit.conf`
(`App AppTests AppSnapshotTests AppUITests Packages`). Medido, da exactamente las 20 sin tocar
`.swiftlint.yml`, pero un directorio nuevo quedaría sin lintar hasta añadirlo, el mismo límite que
ya tiene la lista `FUENTES` de los duplicados.

### Cada tipo de violación se corrige en el código, sin `swiftlint:disable`

- **`force_unwrapping` sobre literales** (las URLs de `GallerySnapshotTests`, el PNG de
  `UploadsSnapshotTests` y los `URLComponents` de `OfflineFixtures.withQuery`): pasan a
  `guard let … else { preconditionFailure("…") }`, el patrón de `AppModule.swift:33`. Siguen
  reventando igual de fuerte si el literal está mal, pero diciendo por qué. En Gallery, un helper
  privado del fichero de test evita escribir el `guard` tres veces. El PNG pasa a un `static let`
  inicializado por un closure.

  *Alternativas descartadas:* `?? valorPorDefecto` tapa un fixture roto y cambia lo que se
  fotografía. `swiftlint:disable:next` en cada caso es justo lo que la regla existe para evitar,
  que es no decir por qué no puede fallar.
- **`function_body_length`:**
  - `OfflineFixtures.makeTransport`: los registros pasan a un
    `private static let exchanges: [InMemoryTransport.Exchange]`, con sus comentarios. La `Task`
    los recorre con `for exchange in exchanges { await transport.register(exchange) }`, con los
    mismos intercambios y en el mismo orden.
  - `CartSnapshotTests.StubLogic.load`: los dos carritos pasan a `private static let`, y `load` se
    queda en un `switch` corto.
  - `SettingsUITests`: el test se parte en helpers privados, uno por bloque de los que ya delimitan
    sus comentarios (tema de marca activado, Diagnostics con el tema de marca, vuelta al tema del
    kit, pinning). El test los llama en el mismo orden y con las mismas aserciones. La firma no lo
    ejecuta, así que se pasa una vez a mano (criterio del proposal).
- **`line_length`:**
  - Los cuerpos JSON de `OfflineFixtures` (líneas 140 y 180): se parten con la continuación de línea
    `\` de los literales multilínea de Swift, que no inserta salto. Los bytes no cambian, y se
    comprueba con un script de un solo uso que compara el literal viejo y el nuevo.
  - `CartUpdateServiceTests.swift:94`: el array literal se reparte en varias líneas.
- **`identifier_name`:** `r` pasa a `recognizer` y `p` a `product`.
- **`large_tuple`:** `setQuantityCalls` pasa a un `struct` con los mismos nombres (`quantity`,
  `lineId`, `cart`), así que los tests que leen `.quantity`, `.lineId` y `.cart` no cambian.
  *Alternativa descartada:* arrays paralelos, que serían dos fuentes para una misma llamada.
- **`todo` (falso positivo):** el comentario de `ProductsViewModel.swift:124` pasa a decir «muere
  del todo», en minúsculas, porque la regla solo busca `TODO` en mayúsculas. *Alternativa
  descartada:* un `disable` por un adverbio.

## Risks / Trade-offs

- **[El import no existe en un clon limpio]** → Qué hace Claude Code en ese caso no está
  documentado. La frase de procedencia de `CLAUDE.md` dice cómo resolverlo, y `/context` enseña si
  cargó.
- **[Unos 20 KB más de contexto en cada sesión]** → Aceptado al pedirlo. Quitar un import cuesta
  una línea.
- **[SwiftLint en otra versión en otra máquina o en CI]** → Una versión nueva puede cambiar
  umbrales o comportamiento de una regla y dar una violación que la otra no ve. `only_rules` evita
  que se activen reglas nuevas sin decidirlo. Fijar la versión queda fuera.
- **[Refactors fuera de la firma: `SettingsUITests` y `OfflineFixtures`]** → `SettingsUITests` se
  pasa una vez a mano. En `OfflineFixtures` se comparan los bytes de los cuerpos y se conservan los
  mismos intercambios en el mismo orden. Los UI tests offline siguen sin ejecutarse en la firma,
  por decisión de `kit.conf`.
- **[CI sigue en rojo]** → Por swift-format y por `check-showcase.sh`, que quedan fuera (proposal).
  Están propuestos como tareas aparte.
- **[`preconditionFailure` en código de la app (`OfflineFixtures`)]** → Solo corre con
  `-UITestOffline` y sustituye un `!` que ya reventaba. El comportamiento es el mismo, con mensaje.
