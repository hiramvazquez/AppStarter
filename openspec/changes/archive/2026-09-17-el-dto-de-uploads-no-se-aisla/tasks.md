## 1. El arreglo

- [x] 1.1 `UploadsService.swift:32` pasa a `private nonisolated struct UploadPayload: Encodable,
      Sendable`. Verificación: `git diff` del fichero toca una sola línea.
      **Hecho**: `private nonisolated struct UploadPayload: Encodable, Sendable`. El diff del
      fichero es esa línea y nada más.
- [x] 1.2 Buscar si queda algún otro DTO de nivel de fichero sin anotar en
      `Packages/*/Sources`, y anotar aquí el resultado con los ficheros encontrados. Si hay
      alguno, se decide por escrito: entra en este cambio o se dice por qué no.
      Verificación: la lista, anotada.
      **Hecho, y el repo queda coherente**: tipos de nivel de fichero que conforman
      `Encodable`/`Decodable`/`Codable` en `Packages/*/Sources` y `App/` hay **tres**, y los
      tres llevan ya la anotación: `AppSettings` (`Networking/AppSettings.swift:17`),
      `StoredSession` (`Domain/Session.swift:6`) y este `UploadPayload`. Los otros 18 están
      anidados dentro del tipo de su petición.

      *Corregido tras la revisión, en dos cosas.* Esta anotación decía que los 18 no necesitan
      la anotación «por estar anidados»: el mecanismo es otro, y lo midió el revisor —lo que
      los exime es que el tipo exterior conforma `BaseRequest`, `Sendable` y de un módulo sin
      `defaultIsolation`; anidar dentro de un tipo cualquiera sin anotar, aunque sea
      `Sendable`, vuelve a fallar—. Y citaba como respaldo el run `34393066732` (2026-09-09),
      que **no vale**: es anterior a `d575e75`, y lo que ese commit cambió no son los DTO sino
      los contextos donde se usan. El respaldo bueno es la sonda local de los criterios, que
      con la palabra puesta deja `Packages/Features` y `Packages/Platform` —tests incluidos—
      sin un solo `[#IsolatedConformances]`.

## 2. La regla escrita

- [x] 2.1 El requisito «Un contrato que implementa un actor se declara nonisolated» de
      `plataforma` gana la mitad de los tipos: que un tipo cuya conformidad se use fuera del
      MainActor SHALL declararse `nonisolated`, con el diagnóstico literal que produce
      incumplirlo, y un escenario. Verificación: el delta, con el texto del requisito de hoy
      conservado.
      **Hecho**: `specs/plataforma/spec.md` como `MODIFIED`. El texto de hoy se conserva
      entero —los tres párrafos de protocolos, su diagnóstico y sus tres escenarios— y el
      requisito gana: la frase de apertura que dice que cubre protocolos **y** tipos, el
      párrafo de los tipos con el diagnóstico literal de `[#IsolatedConformances]`, la nota de
      que el toolchain de Xcode 27 no lo produce y la excepción de los tipos anidados; más dos
      escenarios, «Se añade un DTO que se serializa en una petición» y «Se anota un contrato y
      no el tipo que ese contrato serializa», que es literalmente lo que pasó aquí.
      El nombre del requisito no cambia, y el porqué está en `design.md` D2.

## 3. Cierre

- [x] 3.1 `/kit-verifica` en verde con Xcode 27. Verificación: el resultado, anotado.
      Límite: esta firma NO puede ver el error que motiva el cambio — 6.4 lo acepta. Lo único
      que demuestra es que el arreglo no rompe nada aquí.
      **Hecho**: los nueve pasos en verde, incluido `App · build + AppTests +
      AppSnapshotTests`, firmado contra el árbol y el índice.
      **Y el límite se estrechó**, que es el hallazgo de la revisión: el error SÍ se reproduce
      aquí con `swift build --target UploadsFeature -Xswiftc -disable-upcoming-feature
      -Xswiftc NonisolatedNonsendingByDefault`. Medido por mí en los dos sentidos, sobre una
      copia del scratchpad para el sentido negativo: sin la palabra, `error` en
      `UploadsService.swift:66:38` —mismo fichero, línea y columna que el CI—; con la palabra,
      `Build complete! (1.74 s)`. Primer intento de esta sonda mal leído: conté
      `IsolatedConformances` con `grep` y me dio 1 con el arreglo puesto, porque la palabra
      aparece dentro del comando que el compilador imprime al fallar por otra cosa. Hay que
      filtrar por `[#IsolatedConformances]` y acotar al target.
- [x] 3.2 `/kit-revisa` sobre el diff: ¿esto rompe algo? Es el paso obligatorio de `AGENTS.md`
      antes de archivar. El juez se salta a propósito: el cambio es una palabra y un requisito,
      el alcance no se ha movido, y quien lo acordó es quien lo implementa.
      Verificación: el veredicto, anotado.
      **Hecho — AMBER**: el código no rompe nada, y lo verificó con el compilador, no leyendo:
      el aislamiento de una conformidad no existe en runtime, el tipo es `private`, y con la
      palabra puesta el DTO pasa incluso en contexto `nonisolated` completo. Lo que devolvió
      son dos frases **mías** que afirmaban una evidencia que los logs no dan, y las dos están
      corregidas arriba: que «6.2.4 los compiló todos sin queja en esa misma corrida» —el build
      murió antes, solo compiló ocho módulos— y el respaldo del run del 2026-09-09, que es
      anterior a `d575e75` y por tanto no cubre los contextos nuevos. También corrigió el
      mecanismo que exime a los 18 DTO anidados (`BaseRequest`, no el anidamiento) y encontró
      la sonda local de la 3.1, que este acuerdo declaraba imposible.
      Queda sin hacer, a propósito y fuera de alcance: meter esa sonda en `kit.conf`. No es una
      línea — sobre el paquete entero saca dos errores ajenos y preexistentes
      (`SettingsLogic.swift`, `CartLogic.swift`), así que habría que acotar por target y filtrar
      por grupo de diagnóstico, y eso es decidir qué más vigila la puerta.
- [x] 3.3 **La prueba de verdad**: el job `Features (swift test + archlint)` del CI en verde, y
      `Platform` sin cancelarse. Verificación: el número de run, anotado, y el toolchain que
      ese run imprime.
      Si sigue rojo por el mismo diagnóstico, el arreglo es incorrecto y se replantea D1 por
      escrito, sin ir probando anotaciones a ciegas contra el CI.
      **Hecho — el criterio se cumple**: run `35284398983` (2026-09-17T22:55Z), toolchain
      `/Applications/Xcode_26.3.0.app`, `Apple Swift version 6.2.4`, el mismo que producía el
      error. `Features (swift test + archlint)` **en verde** por primera vez en más de doce
      corridas, y `Platform` en verde también, sin cancelarse. `check-showcase.sh`, verde.

      **Y pasó lo que este acuerdo escribió que pasaría.** El job `App (xcodebuild test: unit +
      snapshot + UI, offline)`, que llevaba doce corridas saltado por el fail-fast, se
      desbloqueó y salió **rojo**: `AppSnapshotTests/CartSnapshotTests.swift:151: error: … failed
      - Snapshot "kit" does not match reference`, 2 fallos de 30 tests; el resto de suites de
      ese job, en verde, y el XCUITest que llegó a correr también. No es una regresión de este
      cambio —este cambio no toca `AppSnapshotTests` ni `App/`— sino la primera medición de ese
      job desde antes del 2026-09-09. Va como hallazgo nuevo, según «Fuera de alcance».

      Vale la pena decir de qué huele: una referencia de snapshot no coincide cuando se grabó
      con un simulador distinto del que corre, y el runner va con el Xcode que le toque
      (26.3.0 hoy) mientras las referencias se graban en local con Xcode 27. Es la misma causa
      de fondo que el rojo que este cambio arregla: aquí y allí no se comprueba lo mismo. Eso
      es del cambio del toolchain, que ya está en marcha aparte.

      Con esto, el CI de `main` NO está «arreglado»: está verde en tres jobs de cinco, con
      `Integration` saltado y `App` rojo por snapshots.
