## Why

Con Xcode 27 (Swift 6.4, SDK de iOS 27) el proyecto no compila: `swift build` muere en
`build planning stopped due to build-tool plugin failures` antes de compilar una línea, y
una vez pasado eso el compilador rechaza los tipos que cruzan la frontera de aislamiento.
Hasta arreglarlo no se puede construir ni la app ni ninguno de los dos paquetes.

Son tres causas independientes, medidas el 2026-09-15 con
`/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/swift build --build-tests`
en cada paquete y `xcodebuild build -project AppStarter.xcodeproj -scheme AppStarter
-destination 'id=0FF64320-70E8-44CD-AC49-F5F8ACA46824' -skipPackagePluginValidation` para la app:

1. **Entorno.** `swift` en el PATH es el de swiftly (Swift 6.3.3, de swift.org) mientras
   Xcode 27 trae Swift 6.4. El frontend de 6.3.3 falla con `unknown argument:
   '-target-arch-variant'` y su PluginAPI no puede cargar `BuildToolPlugin`, así que
   `ArchitectureLint` ni arranca. No es un problema de código, pero es el que esconde a los
   otros dos.
2. **AppFoundation 1.3.1.** Declara `public protocol DomainError: Error, AppErrorConvertible,
   Sendable` sin `nonisolated`, mientras `AppErrorConvertible` y `ScreenError` —a su lado, en
   el mismo paquete— sí lo llevan. Con `defaultIsolation(MainActor)` y el
   `InferIsolatedConformances` más estricto de Swift 6.4, cada tipo que conforma
   `DomainError` rompe con `conformance ... crosses into main actor-isolated code`.
3. **Este repo.** Un protocolo `Sendable` sin anotar queda aislado al MainActor por el
   `defaultIsolation(MainActor)` de los dos `Package.swift`, y entonces un `actor` no puede
   conformarlo: `actor 'X' cannot conform to global-actor-isolated protocol 'Y'`.

## What Changes

- **Se sube el suelo de AppFoundation a `1.3.2`** en los tres manifiestos (`project.yml`,
  `Packages/Platform/Package.swift`, `Packages/Features/Package.swift`). La corrección de
  `DomainError` se hace **upstream**, en el repo de AppFoundation, no aquí: es donde está el
  despiste y donde el resto de la familia (`AppErrorConvertible`, `ScreenError`) ya está
  anotada. **Prerrequisito externo**: sin la 1.3.2 publicada este cambio no se puede terminar.
- **Se marcan `nonisolated` los protocolos que implementa un `actor`**, una línea cada uno:
  - `SessionStoring` — `Packages/Platform/Sources/Domain/Session.swift`
  - `AnalyticsTracking` — `Packages/Platform/Sources/Domain/AnalyticsTracking.swift`
  - `FavoritesStoring` — `Packages/Platform/Sources/Domain/FavoritesStoring.swift`
  - `CameraCapturing` — `Packages/Platform/Sources/Domain/CameraCapturing.swift`
  - `SettingsStoring` — `Packages/Features/Sources/SettingsFeature/Stores/SettingsStore.swift`
  - `UploadsServicing` — `Packages/Features/Sources/UploadsFeature/Services/UploadsService.swift`
  - `GalleryServicing` — `Packages/Features/Sources/GalleryFeatureCore/Services/GalleryService.swift`
- **`TransportMappable` se marca `nonisolated` en el protocolo Y en su `public extension`**
  (`Packages/Platform/Sources/Networking/TransportMappable.swift`). Con la `extension`
  anotada, los conformantes —incluidos los dos enums de `TransportMappableTests`— no
  necesitan tocarse.
- **`DeviceCameraCapture` entra al MainActor por dentro**
  (`Packages/Platform/Sources/CameraKit/CameraKitCapture.swift`): al quedar `CameraCapturing`
  `nonisolated`, `capturePhoto()` deja de ser MainActor y no puede llamar directamente a
  `UIImagePickerController.isSourceTypeAvailable`. El porqué de elegir esto y no lo contrario
  está en `design.md`.
- **Se documenta el requisito de toolchain** en `AGENTS.md`: quién clone el repo con swiftly
  instalado se come el mismo fallo, y el mensaje del compilador no dice en ningún momento que
  el problema sea el toolchain.

## Capabilities

### New Capabilities

Ninguna.

### Modified Capabilities

- `plataforma`: sube el suelo de AppFoundation de `1.3.1` a `1.3.2` en el requisito «Versión
  mínima de los kits», y añade un requisito nuevo sobre el aislamiento de los protocolos que
  cruzan la frontera de un `actor`.

## Fuera de alcance

- **`App/Info.plist`.** Xcode 27 le ha borrado ocho claves por su cuenta
  (`CFBundleDevelopmentRegion`, `CFBundleExecutable`, `CFBundleIdentifier`,
  `CFBundleInfoDictionaryVersion`, `CFBundleName`, `CFBundlePackageType`,
  `CFBundleShortVersionString`, `CFBundleVersion`), que ahora genera él. Ese cambio está sin
  commitear y no lo toca esta propuesta: lo genera xcodegen desde `project.yml`, así que
  decidir si se acepta o se revierte es un cambio propio.
- **`SessionExpiring`** (`Packages/Platform/Sources/Networking/AppSessionState.swift`) no se
  toca. Su conformante `AppSessionState` es `@MainActor` de verdad; anotarlo `nonisolated`
  rompe el build con `main actor-isolated property 'bannerOnNextLogin' can not be mutated from
  a nonisolated context`.
- **El `defaultIsolation(MainActor)` de los dos paquetes** se queda como está. Cambiarlo a
  `nonisolated` en `Packages/Platform` es una conversación que este cambio no abre.
- **Migrar a APIs nuevas de iOS 27.** El deployment target sigue en iOS 17.

## Criterios de aceptación

- [ ] `project.yml`, `Packages/Platform/Package.swift` y `Packages/Features/Package.swift`
      declaran AppFoundation `1.3.2` o superior, y los `Package.resolved` lo resuelven.
- [ ] Ningún fichero de `Packages/` añade `nonisolated` a un tipo que conforme `DomainError`:
      la corrección vive en AppFoundation, y aquí se nota solo en el bump.
- [ ] Los siete protocolos listados en «What Changes» están declarados `nonisolated`, y
      `TransportMappable` lo está también en su `public extension`.
- [ ] `Packages/Platform/Tests/NetworkingTests/TransportMappableTests.swift` no cambia.
- [ ] `Packages/Platform/Sources/Networking/AppSessionState.swift` no cambia.
- [ ] `DeviceCameraCapture.capturePhoto()` compila contra el SDK de iOS 27 sin que
      `CameraCapturing` sea MainActor, y `CameraCapturingMock`
      (`Packages/Features/Tests/UploadsFeatureTests/Mocks/UploadsServiceMock.swift`) sigue
      siendo un `actor`.
- [ ] `AGENTS.md` dice qué toolchain hace falta y cuál es el síntoma exacto de usar otro
      (`unknown argument: '-target-arch-variant'` / `build-tool plugin failures`).
- [ ] `swift build` y `swift test` pasan en `Packages/Platform` y en `Packages/Features` con
      el toolchain de Xcode 27, con la salida pegada en el informe.
- [ ] `xcodebuild build` de la app termina en `** BUILD SUCCEEDED **` contra un simulador de
      iOS 27.
- [ ] `/kit-verifica` en verde.

## Impact

- **Dependencias**: AppFoundation `1.3.1` → `1.3.2` (prerrequisito externo: hay que publicar
  esa versión antes de poder cerrar este cambio).
- **Código**: 9 ficheros de `Packages/` — 7 declaraciones de protocolo, `TransportMappable` y
  `CameraKitCapture.swift`. Ninguno cambia la firma pública de un método ni el
  comportamiento observable; el único con trabajo real es `CameraKitCapture.swift`.
- **Manifiestos**: los tres sitios donde vive el suelo de versión.
- **Documentación**: `AGENTS.md`.
- **Entorno de quien desarrolla**: `swiftly use --global-default xcode`. No es un cambio en el
  repo, pero sin él nada de lo anterior se puede verificar.


---

## Enmienda del 2026-09-15: lo que la revisión midió, y lo que este texto decía mal

La pasada del revisor (AMBER) midió tres afirmaciones de arriba que no se sostienen. No se
reescribe lo anterior: se corrige aquí, y los diez criterios de aceptación siguen tal cual —
todos verificados.

1. **El «Impact» dice que ningún fichero cambia su firma pública ni el comportamiento
   observable. Es falso.** Al anotar `CameraCapturing` como `nonisolated`, `CameraKitCapture`
   y `SimulatedCamera` dejan de ser `@MainActor` **enteros**, no solo su `capturePhoto()`.
   Medido emitiendo la `.swiftinterface` antes y después, con los flags del propio paquete
   para `arm64-apple-ios17.0-simulator`:

   - antes: `@MainActor public struct CameraKitCapture` · `@MainActor public func capturePhoto()`
   - después: `public struct CameraKitCapture` · `nonisolated(nonsending) public func capturePhoto()`

   Hoy no rompe nada, y por qué importa igual: la única cadena viva —`UploadsViewModel`
   (`@MainActor`) → `UploadsLogic` → `camera.capturePhoto()`— arranca en el main actor, y
   `nonisolated(nonsending)` hereda el aislamiento de quien llama, así que el render UIKit de
   `SimulatedCamera` se sigue ejecutando ahí. Lo que cambia es el **contrato**: ese render ya
   no está clavado al main actor, y el primer llamante que no esté en él —un `Task.detached`,
   un test `nonisolated`, una feature futura— lo ejecutará fuera sin que el compilador lo
   impida. Queda como deuda escrita; no se arregla en este cambio.

2. **El riesgo «el salto al MainActor añade una suspensión» está al revés.** El salto se
   **elimina**: `capturePhoto()` pasa a heredar el aislamiento de quien llama.

3. **El riesgo que justifica el `xcodebuild` está mal razonado, y ese criterio mide otra
   cosa.** `#if os(iOS)` también es cierto en el simulador, así que `DeviceCameraCapture` sí
   se compila ahí; lo que no se compila en simulador es su **llamada**, bajo
   `#if targetEnvironment(simulator) … #else`. El `xcodebuild` contra un simulador, por tanto,
   no verifica el único punto con riesgo real: llamar a un `init()` `@MainActor` desde un
   `capturePhoto()` ya `nonisolated`. Lo verificó la revisión por fuera —
   `swiftc -typecheck -target arm64-apple-ios17.0 -sdk iPhoneOS27.0.sdk` sobre
   `Sources/CameraKit`, limpio— y comprobó que esa rama está viva metiendo un error
   deliberado y viendo al compilador cazarlo.

4. **Dato caducado.** «Fuera de alcance» dice que el borrado de ocho claves de
   `App/Info.plist` está sin commitear; ya lo está (`e482f7f`), así que ese párrafo describe
   un estado que no existe.
