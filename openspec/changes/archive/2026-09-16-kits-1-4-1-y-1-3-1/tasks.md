## 1. Suelo de versión

- [x] 1.1 Subir AppFoundation a `1.4.1` y CoreNetworking a `1.3.1` en `project.yml`,
      `Packages/Platform/Package.swift` y `Packages/Features/Package.swift`, y verificar con
      `grep -n "from:"` que los tres declaran las dos cifras nuevas.
- [x] 1.2 Resolver en los dos paquetes (`swift package update`) y en el proyecto
      (`xcodegen generate` + `xcodebuild -resolvePackageDependencies`), y verificar que los
      tres `Package.resolved` fijan `appfoundation 1.4.1` y `corenetworking 1.3.1`.

## 2. Que nada más se haya movido

- [x] 2.1 Verificar que `git diff --stat` no lista nada bajo `Sources/`, `Tests/`, `App/`,
      `AppTests/`, `AppSnapshotTests/` ni `AppUITests/` — solo los tres manifiestos y los dos
      `Package.resolved` versionados. Si aparece algo más, el cambio se salió de su alcance y
      hay que parar y decirlo, no arreglarlo de paso.
      *(Redacción corregida el 2026-09-16: decía «ningún fichero `.swift`», que excluía los
      `Package.swift` que este cambio tiene que tocar.)*

## 3. Verificación

- [x] 3.1 `swift build --build-tests` y `swift test` en `Packages/Platform`, con la última
      línea pegada en el informe.
- [x] 3.2 `swift build --build-tests` y `swift test` en `Packages/Features`, con la última
      línea pegada en el informe.
- [x] 3.3 `xcodebuild test -project AppStarter.xcodeproj -scheme AppStarter -destination
      'id=29EF56C0-25A0-4E20-B4DF-B06233CE4534' -skipPackagePluginValidation
      -only-testing:AppTests -only-testing:AppSnapshotTests` (iPhone 17 Pro, el simulador con
      el que se grabaron las referencias) termina en `** TEST SUCCEEDED **`.
- [x] 3.4 `/kit-revisa` sobre el diff: ¿esto rompe algo?
- [x] 3.5 `/kit-verifica` en verde.

- Ronda 1 del juez: DEVUELTO · comportamiento: no

Tres errores de hecho en el `proposal.md`, todos censos mal contados por mí y todos corregidos
en prosa: (1) AppFoundation cambia dos declaraciones públicas, no una — mi `grep` no incluía
`let`; (2) CoreNetworking sí añade dos públicas en `CoreNetworkingTestSupport`, que mi diff
dejaba fuera; (3) `iPhone 17e` no es el único simulador con iOS 27 —hay once— y la regla de los
snapshots es sobre tamaño de pantalla, no sobre nombre de dispositivo. Ninguno cambia el código
entregado. Más el bookkeeping: 3.4 estaba sin marcar y 3.5 sin correr.

Además, al recoger los XCUITests que quedaron lanzados: 4 fallan igual en baseline y con el
bump, y `FullFlowTests` es flaky en los dos. No es la migración; queda medido en el proposal.
