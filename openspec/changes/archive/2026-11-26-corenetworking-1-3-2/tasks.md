## 1. Suelo de versión

- [x] 1.1 Subir CoreNetworking a `1.3.2` en `project.yml`, `Packages/Platform/Package.swift` y
      `Packages/Features/Package.swift`, sin tocar la línea de AppFoundation. Verificación:
      `grep -n "from:"` en los tres lista CoreNetworking `1.3.2` y AppFoundation `1.4.2`.
- [x] 1.2 Resolver en los dos paquetes (`swift package update`) y en el proyecto
      (`xcodegen generate` + `xcodebuild -resolvePackageDependencies`). Verificación: los dos
      `Package.resolved` versionados y el del workspace fijan `corenetworking 1.3.2` y
      `appfoundation 1.4.2`.

## 2. Que nada más se haya movido

- [x] 2.1 `git diff --stat` no lista nada fuera de los tres manifiestos, los dos
      `Package.resolved` versionados y `openspec/`. Si aparece algo más, el cambio se salió de
      su alcance: se para y se dice, no se arregla de paso.

## 3. Verificación

- [x] 3.1 `swift build --build-tests` y `swift test` en `Packages/Platform`, con la última
      línea pegada aquí.
      *(2026-11-26, Swift 6.4: `Build complete! (7.38 s)`; `swift test` corre un proceso por
      target y termina con `✔ Test run with 13 tests in 4 suites passed` y
      `✔ Test run with 1 test in 1 suite passed`. 14 tests, ninguno falla.)*
- [x] 3.2 `swift build --build-tests` y `swift test` en `Packages/Features`, con la última
      línea pegada aquí.
      *(2026-11-26, Swift 6.4: `Build complete! (9.59 s)`; 12 procesos de test, el último
      `✔ Test run with 60 tests in 7 suites passed`. 219 tests en total, ninguno falla.)*
- [x] 3.3 `xcodebuild test -project AppStarter.xcodeproj -scheme AppStarter -destination
      'id=29EF56C0-25A0-4E20-B4DF-B06233CE4534' -skipPackagePluginValidation
      -only-testing:AppTests -only-testing:AppSnapshotTests` (iPhone 17 Pro, el simulador de
      las referencias) termina en `** TEST SUCCEEDED **`, y `git status` no muestra cambios en
      `AppSnapshotTests/__Snapshots__/`.
      *(2026-11-26, Xcode 27: `Executed 30 tests, with 0 failures (0 unexpected)` y
      `** TEST SUCCEEDED **`; `git status --short AppSnapshotTests` sale vacío.)*
- [x] 3.4 Stagear por nombre, `/kit-verifica` y `/kit-revisa` sobre la rodaja. Verificación:
      firma verde y revisor sin hallazgos que bloqueen; se anotan aquí el `verificado:` de la
      firma y el veredicto con su ronda.
      *(2026-11-26: firma `verificado: 2026-11-26T14:36:12Z`, `diff: fd76e7fb…`,
      `resultado: verde`, Swift 6.4 · Xcode 27.0, 11/11 pasos. `/kit-revisa`: **GREEN**, ronda 1
      de un presupuesto de 1; punto marcado. Cuatro hallazgos opcionales: (1) el «Riesgo» del
      proposal decía que el techo solo alcanzaba al refresco de token, y alcanza también a la
      `RetryPolicy` por defecto de los `APIService` del repo; corregido por escrito y con fecha
      en el proposal, sin tocar lo entregado; (2) el 401 con `Retry-After` > 16 s ya está
      descrito, y cambiar la `RetryPolicy` es fuera de alcance; (3) el CI con Xcode 26.3 sigue
      pendiente, en «Workflow follow-up»; (4) el aviso de requisito largo es anterior.)*
- [x] 3.5 `/kit-verifica` en verde sobre el árbol que se commitea.
      *(2026-11-26: después de la 3.4 solo cambió `openspec/`, que la firma no cubre; la firma
      de las 14:36:12Z sigue siendo la del árbol que se commitea, y la puerta lo confirma:
      `.git/hooks/pre-commit` sale con `exit=0` sobre el índice final.)*

## Workflow follow-up

- Commit por la puerta del kit. El push lo decide el owner: se para y se pregunta.
- El CI del commit (Xcode 26.3) tiene que salir en verde antes de archivar; es el único que
  prueba la subida con el toolchain del CI.
- Archivar: el delta modifica «Versión mínima de los kits» en `openspec/specs/plataforma`.
