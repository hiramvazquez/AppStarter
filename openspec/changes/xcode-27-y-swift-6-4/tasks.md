## 1. Entorno (antes de nada: sin esto no se puede medir)

- [x] 1.1 Seleccionar el toolchain de Xcode 27 (`swiftly use --global-default xcode`) y
      verificar que `swift --version` imprime la misma versión que
      `xcrun swift --version` (Swift 6.4), no la 6.3.3 de swiftly.
- [x] 1.2 Verificar que `cd Packages/Platform && swift build` ya NO muere en
      `build planning stopped due to build-tool plugin failures` — los errores que salgan
      a partir de aquí son de código, que es lo que arreglan los grupos siguientes.

## 2. Prerrequisito externo: AppFoundation 1.3.2

- [x] 2.1 Clonar `https://github.com/hiramvazquez/AppFoundation.git` (no está en esta
      máquina) y verificar que `Sources/AppFoundation/Architecture/AppError/DomainError.swift`
      declara `public protocol DomainError:` sin `nonisolated`.
- [x] 2.2 Marcar `nonisolated` el `protocol DomainError` y su `extension DomainError`, y
      verificar que la suite del propio paquete sigue en verde (`swift build`, `swift test`).
- [x] 2.3 **(ampliación acordada el 2026-09-15 — ver `design.md`, decisión 5)** Marcar
      `nonisolated` los protocolos generados por las plantillas del generador
      (`Templates/Service.swift.txt`, `Templates/Store.swift.txt`, `Templates/Logic.swift.txt`),
      y arreglar la sonda de R1 de `Scripts/verify-generator.sh` (el `let` opcional que
      inyecta necesita `= nil`, o el compilador corta antes de que ArchLint emita su
      diagnóstico). Verificar que `Scripts/verify-generator.sh` pasa entero — hoy falla con
      `actor 'ProductsServiceMock' cannot conform to global-actor-isolated protocol
      'ProductsServicing'` sobre el código que él mismo genera.
- [x] 2.4 Publicar la versión `1.3.2` y verificar que el tag es visible
      (`git ls-remote --tags` lo lista). **Lo ejecuta Hiram, no el agente.**

## 3. Suelo de versión en este repo

- [x] 3.1 Subir AppFoundation a `1.3.2` en `project.yml`,
      `Packages/Platform/Package.swift` y `Packages/Features/Package.swift`, y verificar
      que los tres `Package.resolved` lo resuelven tras
      `swift package update` / `xcodebuild -resolvePackageDependencies`.
- [x] 3.2 Verificar que, solo con el bump, desaparecen los errores
      `conformance ... crosses into main actor-isolated code` de los tipos de error de
      dominio, y que ningún fichero de `Packages/` ha necesitado anotarse para conseguirlo.

## 4. Protocolos que implementa un `actor`

- [x] 4.1 Marcar `nonisolated` `SessionStoring`
      (`Packages/Platform/Sources/Domain/Session.swift`), `AnalyticsTracking`
      (`Packages/Platform/Sources/Domain/AnalyticsTracking.swift`) y `FavoritesStoring`
      (`Packages/Platform/Sources/Domain/FavoritesStoring.swift`), y verificar que
      `cd Packages/Platform && swift build --build-tests` deja de dar
      `actor 'X' cannot conform to global-actor-isolated protocol 'Y'` para
      `SessionStoreSpy`, `InMemoryAnalytics` y `FavoritesStoreMock`.
- [x] 4.2 Marcar `nonisolated` el `protocol TransportMappable` **y** su `public extension`
      (`Packages/Platform/Sources/Networking/TransportMappable.swift`), y verificar que
      `Packages/Platform/Tests/NetworkingTests/TransportMappableTests.swift` compila SIN
      tocarse (`git diff --stat` no lo lista).
- [x] 4.3 Marcar `nonisolated` `SettingsStoring`
      (`Packages/Features/Sources/SettingsFeature/Stores/SettingsStore.swift`),
      `UploadsServicing` (`Packages/Features/Sources/UploadsFeature/Services/UploadsService.swift`)
      y `GalleryServicing` (`Packages/Features/Sources/GalleryFeatureCore/Services/GalleryService.swift`),
      y verificar que `cd Packages/Features && swift build --build-tests` compila
      `InMemorySettingsStore`, `UploadsServiceMock` y `GalleryServiceMock` sin que dejen de
      ser `actor`s.
- [x] 4.4 Verificar que `Packages/Platform/Sources/Networking/AppSessionState.swift` NO se
      ha tocado (`SessionExpiring` se queda sin anotar) y que el build sigue en verde.

## 5. Cámara

- [x] 5.1 Marcar `nonisolated` `CameraCapturing`
      (`Packages/Platform/Sources/Domain/CameraCapturing.swift`) y verificar que el único
      error nuevo en todo el repo es el de `isSourceTypeAvailable` en
      `Packages/Platform/Sources/CameraKit/CameraKitCapture.swift`.
- [x] 5.2 En `CameraKitCapture.swift`, mover el cuerpo de `DeviceCameraCapture.capturePhoto()`
      a un método privado `@MainActor` y dejar `capturePhoto()` `nonisolated` esperándolo
      (`ImagePickerCoordinator` se queda `@MainActor`), y verificar que
      `xcodebuild build -project AppStarter.xcodeproj -scheme AppStarter -destination
      'platform=iOS Simulator,OS=27.0,...' -skipPackagePluginValidation` termina en
      `** BUILD SUCCEEDED **` — es el único comando que compila esa rama, porque
      `swift build` de `Packages/Platform` apunta a macOS.
- [x] 5.3 Verificar que `CameraCapturingMock`
      (`Packages/Features/Tests/UploadsFeatureTests/Mocks/UploadsServiceMock.swift`) sigue
      declarado como `actor` y que los tests de `UploadsFeatureTests` pasan.

## 6. Documentación

- [x] 6.1 Añadir a `AGENTS.md` qué toolchain hace falta y el síntoma de usar otro
      (`unknown argument: '-target-arch-variant'`,
      `build planning stopped due to build-tool plugin failures`), y verificar releyéndolo
      que alguien que solo tenga ese mensaje llega al arreglo sin ayuda.

## 7. Cierre

- [x] 7.1 `swift test` en `Packages/Platform` y en `Packages/Features`, con la última línea
      de cada uno pegada en el informe.
- [x] 7.2 `/kit-verifica` en verde.

- Ronda 1 del juez: ACUERDO-ROTO · comportamiento: no
  Tres errores de texto, ninguno de código: el dato del `Info.plist` de la enmienda (falso,
  corregido arriba), el censo «once tipos» de `design.md` y el criterio 8, que pide una
  evidencia que el repositorio no guarda. Los diez criterios se verificaron cumplidos.

- Ronda 2 del juez: sin veredicto de vuelta · comportamiento: no
  Confirma las tres correcciones —reprodujo el `xcodegen` del `Info.plist`— y deja dos
  residuos de texto, ambos números: el «once» de `design.md`, que aquí se elimina en vez de
  recontarse, y un «seis líneas» que había fabricado la ronda anterior. Sin más rondas: dos
  seguidas sin tocar comportamiento no las decide una tercera.
