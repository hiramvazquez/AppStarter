# Tareas

- [x] 1. Subir `Packages/Platform` a AppFoundation 1.3.1 / CoreNetworking 1.2.2
- [x] 2. Subir `Packages/Features` a las mismas versiones
- [x] 3. Subir el lockfile del `.xcodeproj`
- [x] 4. `swift build` + `swift test` en Platform
- [x] 5. `swift build` + `swift test` en Features
- [x] 6. ~~Adoptar~~ **AUDITAR** `cancelsInFlightWorkOnRemoval`: el default es `true`, así
       que la tarea real era encontrar dónde ese default es el equivocado → Uploads
- [x] 7. Build de la app (xcodebuild) en verde


## Resultado

- Platform: build + 8 tests ✅ · Features: build + 125 tests ✅
- App: `xcodebuild build` ✅ · AppTests: 11 tests ✅
- El suelo de versión vivía en TRES sitios (`project.yml` + los dos `Package.swift`);
  mover solo los lockfiles no bastaba — el resolutor se quedaba en 1.2.3.
