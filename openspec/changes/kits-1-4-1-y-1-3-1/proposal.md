## Why

AppFoundation `1.4.1` y CoreNetworking `1.3.1` salieron el 2026-09-16 y traen cambios de
lenguaje, no solo arreglos: los dos activan las seis *upcoming features* con baseline Swift 7
(`ExistentialAny`, `InternalImportsByDefault`, `MemberImportVisibility`,
`ImmutableWeakCaptures`, además de las dos de concurrencia que ya llevaban). Quedarse en
`1.3.2`/`1.2.2` deja al proyecto por detrás de sus propios kits sin ganar nada.

**Medido el 2026-09-16, antes de escribir este acuerdo: la migración no rompe ni una línea de
este repo.** La verificación se hizo en dos `git worktree` desechables fuera del árbol de
trabajo, que no se tocó. Esto importa porque cambia la forma del cambio: no es una migración,
es un bump.

Las dos razones por las que no rompe, y las dos están comprobadas y no supuestas:

- **Las *upcoming features* son por módulo.** Se aplican al paquete que las declara y no se
  propagan a quien lo consume, así que no obligan a AppStarter a escribir `any`, ni a importar
  explícitamente, ni a nada.
- **`InternalImportsByDefault` sí podía romper** quitando las reexportaciones de las que vive
  un consumidor, y no lo hace porque los dos paquetes añadieron `public import` donde su API
  pública expone tipos de otro módulo (`Foundation`, `Observation` y `SwiftUI` en
  AppFoundation; `Foundation` y `CoreNetworking` en CoreNetworking).

Hay un tercer vector que el argumento anterior NO cubre y que conviene dejar escrito, porque
la próxima subida sí puede llegar por ahí: AppFoundation no solo envía una librería, envía los
*build-tool plugins* `ArchitectureLint` y `SwiftLint`, que corren sobre **nuestras** fuentes.
Una regla nueva rompe código que nadie ha tocado, y «las *upcoming features* son por módulo»
no dice nada de eso. Medido para esta subida: entre `1.3.2` y `1.4.1`, `Plugins/` no cambia y
`Sources/archlint/Rules.swift` cambia una sola línea (`+import Observation`). No hay reglas
nuevas. *(Lo señaló el revisor; el argumento original se apoyaba solo en la modularidad.)*

AppFoundation cambia **dos** declaraciones públicas entre `1.3.2` y `1.4.1`, las dos en
`Sources/AppFoundation/Architecture/AppError/WrappedError.swift` y las dos de la misma forma
—`Error` → `any Error`, mismo tipo, distinta escritura—: `public let underlying` y
`public var rootCause`. `grep -rn "WrappedError\|rootCause\|\.underlying"` sobre `Packages/`,
`App/`, `AppTests/`, `AppSnapshotTests/` y `AppUITests/` no devuelve ninguna ocurrencia.

CoreNetworking no cambia ni elimina ninguna declaración pública existente entre `1.2.2` y
`1.3.1`; lo que hace es **añadir** dos en `Sources/CoreNetworkingTestSupport/MockURLProtocol.swift`
(`cancelledDeliveries(method:url:)` y `waitForCancelledDelivery(...)`), que este repo no usa.
Todo aditivo, y por eso no rompe.

*(Corregido el 2026-09-16 tras el juez: la redacción original decía «el único cambio … es
`rootCause`» y «CoreNetworking no cambia ninguna declaración pública». Las dos eran censos mal
contados — el `grep` con el que las medí no incluía `let`, y el diff de CoreNetworking estaba
acotado a `Sources/CoreNetworking/`, dejando fuera `CoreNetworkingTestSupport`.)*

## What Changes

- **Sube el suelo de AppFoundation a `1.4.1` y el de CoreNetworking a `1.3.1`** en los tres
  sitios donde vive: `project.yml`, `Packages/Platform/Package.swift` y
  `Packages/Features/Package.swift`.
- **Los tres `Package.resolved` pasan a resolver esas versiones**
  (`Packages/Platform`, `Packages/Features` y el del workspace de `AppStarter.xcodeproj`).

No se toca ningún fichero de código Swift: los dos `Package.swift` que cambian son
manifiestos, no fuentes. En el diff de git son cinco ficheros —los tres manifiestos y los dos
`Package.resolved` de los paquetes—; el tercer `Package.resolved`, el del workspace de
`AppStarter.xcodeproj`, también cambia pero no está versionado, porque el `.xcodeproj` lo
genera xcodegen y está fuera de git.

*(Corregido el 2026-09-16, al implementar: la redacción original decía «no se toca ningún
fichero `.swift`» y «seis ficheros». Lo primero se contradecía con el propio cambio —los
`Package.swift` son `.swift`— y lo segundo contaba un fichero que git no ve.)*

## Capabilities

### New Capabilities

Ninguna.

### Modified Capabilities

- `plataforma`: el requisito «Versión mínima de los kits» sube las dos cifras. El motivo
  vigente del suelo anterior —AppFoundation `1.3.2` es la primera que compila bajo Swift 6.4,
  porque antes `DomainError` quedaba aislado al MainActor— no se pierde al reescribirlo: sigue
  siendo la razón por la que no se puede bajar de ahí.

## Fuera de alcance

- **Activar en AppStarter las seis *upcoming features* de baseline Swift 7.** Es lo que
  hicieron los kits y es tentador seguirles, pero es un cambio propio, con su propio coste de
  migración, y subir la dependencia no lo necesita para nada.
- **Regrabar los snapshots.** Las referencias de `AppSnapshotTests/__Snapshots__/` están
  grabadas en `iPhone 17 Pro` y siguen valiendo; ver «Falsa alarma» abajo.
- **CI, XCUITests y el mínimo de iOS/macOS.** La migración no los rompe, así que no se tocan.
  Los XCUITests **no** están verdes en esta máquina, y está medido que eso es anterior al
  cambio: `DiagnosticsUITests`, `GalleryUITests`, `SettingsUITests` y `UploadsUITests` fallan
  igual con `1.3.2`/`1.2.2` que con `1.4.1`/`1.3.1`, en ejecuciones en serie sobre
  `iPhone 17 Pro`. `FullFlowTests.testFullFlowLoginToLogout()` es flaky en los dos —aislado y
  repetido: baseline pasa/falla/pasa, bump falla/falla/pasa—, así que tampoco es atribuible a
  las versiones. Arreglarlos es un cambio propio.
- Añadir features o refactorizar lo que ya funciona.

## Falsa alarma, escrita aquí para que no se repita

En la primera pasada fallaron 30 tests de `AppSnapshotTests` y parecía rotura de la migración.
No lo era: se habían corrido en `iPhone 17e`, cuya pantalla no es la de las referencias.
`AppSnapshotTests/SnapshotHelpers.swift` ya lo avisa en su propio comentario — el tamaño sale
de `UIScreen.main.bounds.size` del simulador que corre el test, nunca de un valor fijo.

Lo que decide si esta suite significa algo es **el tamaño de pantalla**, no el nombre del
dispositivo ni la versión de iOS. Las referencias miden 1206×2622 px, que son 402×874 pt @3x:
ese tamaño lo dan tanto `iPhone 17 Pro` como `iPhone 17`, y de hecho `kit.conf` verifica con
`name=iPhone 17` y sale verde.

Comprobado montando un segundo worktree **sin subir versiones**: falla exactamente el mismo
conjunto de 30 tests. Es preexistente y depende del simulador elegido, no de las versiones de
los kits.

*(Corregido el 2026-09-16 tras el juez. La redacción original decía que `iPhone 17e` era «el
único simulador con runtime de iOS 27 en esta máquina» —hay once, `iPhone 17` entre ellos— y
escribía la regla por nombre de dispositivo cuando en realidad es sobre tamaño. Por ese hueco
volvía a colarse justo el susto que esta sección existe para evitar.)*

## Criterios de aceptación

- [ ] `project.yml`, `Packages/Platform/Package.swift` y `Packages/Features/Package.swift`
      declaran AppFoundation `1.4.1` y CoreNetworking `1.3.1`.
- [ ] Los tres `Package.resolved` resuelven `appfoundation 1.4.1` y `corenetworking 1.3.1`.
- [ ] `git diff --stat` no lista nada bajo `Sources/`, `Tests/`, `App/`, `AppTests/`,
      `AppSnapshotTests/` ni `AppUITests/` — solo los tres manifiestos y los dos
      `Package.resolved` versionados.
- [ ] `swift build` y `swift test` pasan en `Packages/Platform` y en `Packages/Features`, con
      la última línea de cada uno pegada en el informe.
- [ ] `xcodebuild test -only-testing:AppTests -only-testing:AppSnapshotTests` contra
      `iPhone 17 Pro` termina en `** TEST SUCCEEDED **`.
- [ ] `AppSnapshotTests/__Snapshots__/` no cambia.
- [ ] `/kit-verifica` en verde.

## Impact

- **Dependencias**: AppFoundation `1.3.2` → `1.4.1`, CoreNetworking `1.2.2` → `1.3.1`. Ambas
  publicadas y resolubles.
- **Código**: ninguno.
- **Manifiestos y lockfiles**: cinco ficheros en git (los tres manifiestos y los dos
  `Package.resolved` de los paquetes), más el `Package.resolved` del workspace de
  `AppStarter.xcodeproj`, que cambia pero no está versionado.
- **Riesgo**: bajo y medido. Lo que queda por confirmar al implementar es que la resolución en
  el árbol real reproduce lo medido en el worktree.
