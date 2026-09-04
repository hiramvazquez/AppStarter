# AppStarter

Una app iOS real — login, catálogo de productos, detalle, favoritos y perfil — que
consume [`AppFoundation`](https://github.com/hiramvazquez/AppFoundation) 1.2.1 y
[`CoreNetworking`](https://github.com/hiramvazquez/CoreNetworking) 1.0.0 contra la API
pública [DummyJSON](https://dummyjson.com). Es la plantilla de arranque: clónala, cambia
el dominio y las pantallas, y ya tienes la arquitectura, el generador y el linter
funcionando desde el primer commit — en la estructura **modular de tres niveles** que deja
`archinit --multi` (PRD-AF-10), no en un único paquete local.

## Qué es

- **Proyecto**: [xcodegen](https://github.com/yonaskolb/XcodeGen) genera
  `AppStarter.xcodeproj` desde `project.yml` — el `.xcodeproj` no se versiona.
- **Arquitectura**: View → ViewModel → Logic → Services/Stores (la de `AppFoundation`),
  sin excepciones, con `ArchitectureLint` activo en cada `swift build` y R13 (aislamiento
  entre módulos) vigilando que ninguna feature importe otra.
- **Once pantallas + una hoja modal**: Login, Productos (lista paginada), Detalle de
  producto (favorito ⭐, `chrome: .custom` a propósito, entrada a Gallery), Favoritos
  (SwiftData, "Vaciar favoritos" con `AlertState` destructiva), Perfil (`GET /auth/me`,
  logout con confirmación, muestra cuándo se renovó el token en silencio, entrada a
  Settings), Buscar (sheet, barra custom `.blur` con `SearchBarConfiguration` y
  `Debouncer`), **Diagnostics** (escaparate de `CoreNetworking`: siete experimentos
  reales contra DummyJSON — 404, 401, timeout, JSON inválido, host inalcanzable, 5xx
  con reintentos, petición lenta cancelable — más `.untrustedServer` cuando `Settings`
  tiene el pin falso activo), **Uploads** (`POST /products/add` con
  `upload(_:data:progress:)`, una foto vía `any CameraCapturing`, y progreso real),
  **Gallery** (imágenes grandes de un producto, barra custom `.transparent` en
  `.overlay`, `Throttler` para prefetch, miniaturas con `PhaseView`/
  `BindingBackedState`) y **Settings** (tema del kit/de marca en vivo, pinning TLS con
  pines reales de `dummyjson.com` + un pin falso, `AppEnvironment`, configuración de red
  activa, últimos eventos de analítica).
- **Deep links**: `appstarter://product/<id>` y `appstarter://search?q=<query>` —
  `App/DeepLink.swift`.
- **Sesión**: bearer token + refresh automático en 401, con logout global si el refresh
  también falla. `Container(parent:)` por sesión: al hacer login se crea un contenedor
  hijo con los módulos autenticados (hoy, `Profile`); al cerrar sesión se descarta.
- **Analítica**: `AnalyticsTracking` (`Domain`) — un evento `screen_view` por navegación
  (`App/RootView.swift`) y uno `upload` al subir una foto, con un adaptador de consola
  que además guarda los últimos eventos en memoria — `Settings` los muestra.

## Arranca en 5 minutos

```bash
git clone https://github.com/hiramvazquez/AppStarter.git
cd AppStarter
./Scripts/bootstrap.sh
open AppStarter.xcodeproj
```

`bootstrap.sh` es `xcodegen generate` — instala xcodegen antes si hace falta
(`brew install xcodegen`). Selecciona el esquema **AppStarter**, el simulador **iPhone
17 Pro**, y ejecuta (⌘R). Usuario de prueba: `emilys` / `emilyspass`.

Primer build en Xcode: aparecerá un diálogo para **confiar** en los plugins de SwiftPM
(`ArchitectureLint` de AppFoundation) — acéptalo una vez. Desde línea de comandos,
`xcodebuild` necesita `-skipPackagePluginValidation` (ver
`docs/INFORME-INTEGRACION.md`, fricción 5).

## Cómo está organizado

Estructura de tres niveles — la que deja `archinit --multi` aplicada sobre lo que ya
existía (`docs/INFORME-MULTI.md` documenta la migración paso a paso y cada fricción nueva
del kit, con repro):

```
AppStarter/
├── project.yml                  targets, esquema, dependencias SPM
├── Scripts/bootstrap.sh          xcodegen generate
├── App/                          cáscara fina de xcodegen — target `AppStarter`
│   ├── AppStarterApp.swift        @main: instala AppErrorPresenter, registra AppModule.makeModules(), onOpenURL
│   ├── AppModule.swift            composition root: PlatformModule (navegación, CameraKit, AnalyticsAdapters)
│   │                              + NetworkingModule + un módulo por feature
│   ├── RootView.swift             CoordinatorView + switch sobre AppRoute (Domain) + tema en vivo (ThemeSettings)
│   ├── AppErrorPresenter.swift    mapeo DomainError → ScreenError, instalado en @main
│   ├── DeepLink.swift             appstarter://product/<id>, appstarter://search?q=<query>
│   ├── Theme/                     Brand (tokens) + los cuatro Brand…Style (Settings los instala/quita)
│   └── OfflineFixtures.swift      InMemoryTransport con respuestas grabadas (-UITestOffline)
├── AppTests/                     smoke test nativo de Xcode del composition root + DeepLinkTests
├── AppUITests/                   los XCUITests del PRD + el helper de arranque compartido
├── Packages/
│   ├── Platform/                  1 Package.swift — Domain, Networking, CameraKit, AnalyticsAdapters
│   │   ├── Sources/Domain/          modelos y protocolos compartidos: Product (con images),
│   │   │                            UserProfile, StoredSession/SessionStoring, FavoritesStoring,
│   │   │                            AnalyticsTracking (con recentEvents()), AppRoute — SOLO Foundation
│   │   ├── Sources/Networking/      lo que necesita CoreNetworking pero es transversal a
│   │   │                            varias features: AuthServicing/ProductsServicing,
│   │   │                            AppSessionState/SessionExpiring, RefreshActivityLog,
│   │   │                            AppSettings/ThemeSettings/PinningPins (Settings), NetworkingModule
│   │   ├── Sources/CameraKit/       stub de CameraProviding (Fase 2 lo usa de verdad)
│   │   ├── Sources/AnalyticsAdapters/  stub de AnalyticsAdapting (consola; Fase 2)
│   │   └── Sources/PlatformTestSupport/  mocks/spies compartidos por más de un *FeatureTests
│   │                                     (SessionStoreSpy, ProductsServiceMock, FavoritesStoreMock,
│   │                                     InMemoryAnalytics, ObservationFlag…)
│   └── Features/                  1 Package.swift — un target <Name>Feature por feature
│       ├── Sources/LoginFeature/ ProductsFeature/ ProductDetailFeature/ FavoritesFeature/
│       │                         ProfileFeature/ SearchFeature/ DiagnosticsFeature/ UploadsFeature/
│       │                         SettingsFeature/  (View/ViewModel/Logic/Module + Services/Stores)
│       ├── Sources/GalleryFeatureCore/ GalleryFeatureUI/  (--module: dos targets reales)
│       └── Tests/<Name>FeatureTests/    unitarios por capa · IntegrationTests/ (cross-feature)
└── docs/
    ├── INFORME-INTEGRACION.md    fricciones al integrar los paquetes desde Xcode (histórico)
    ├── INFORME-MULTI.md          la migración a modo multi, paso a paso, y sus fricciones nuevas
    ├── INFORME-CALIDAD.md        calibración de SwiftLint
    └── ISSUES.md                 issues propuestas para AppFoundation/CoreNetworking
```

### Por qué dos manifiestos SPM locales (`Packages/Platform`, `Packages/Features`)

`generate-feature`/`archinit`/`archlint` son **command plugins de SwiftPM**: necesitan un
`Package.swift` real sobre el que invocarse. Un `.xcodeproj` de xcodegen no lo ofrece por
sí solo — de ahí los dos paquetes locales en `Packages/`, no uno por feature (eso
recompilaría demasiado y consultaría la red al resolver en cada cambio de scheme,
`MultiModule.md` § Overview). `App/` (el target de xcodegen) es una cáscara fina que solo
resuelve `ViewModel`s desde `Container.shared` y monta la navegación; toda la lógica de
negocio vive en los targets reales de `Packages/Platform` y `Packages/Features`.
`swift build`/`swift test --package-path Packages/<Platform|Features>` funcionan
directamente, sin abrir Xcode.

## El kit, usado de verdad

```bash
# Una vez, sobre el repo (idempotente — no pisa lo que ya existe):
Scripts/bootstrap-multi.sh AppStarter --capability Camera --adapter Analytics
# → Packages/Platform (Domain/CameraKit/AnalyticsAdapters), Packages/Features (manifiesto
#   con los markers archinit:features-*/products-*), .archlint.yml raíz con `modules:`

# Por feature (Fase 2 — el escaparate de PRD-APP-02 añade pantallas nuevas así):
cd Packages/Features
swift package --allow-writing-to-package-directory generate-feature Gallery --api --module
```

`generate-feature` en modo multi da de alta el target (y su test target) entre los
markers `archinit:features-begin/end`/`archinit:products-begin/end` de
`Packages/Features/Package.swift`, y — best-effort — el `import`/`case`/módulo en
`App/AppModule.swift`/`App/AppRoute.swift` (aquí ese último best-effort no aplica:
`AppRoute` vive en `Packages/Platform/Sources/Domain/AppRoute.swift`, no en `App/`, ver
`docs/INFORME-MULTI.md`). Los seis features actuales (Login, Products, ProductDetail,
Favorites, Profile, Search) se movieron A MANO desde el antiguo paquete único
`AppStarterKit/` siguiendo exactamente esa forma — `docs/INFORME-MULTI.md` documenta el
proceso paso a paso y cada fricción encontrada, con repro.

### Añadir una feature nueva

```bash
cd Packages/Features
swift package --allow-writing-to-package-directory generate-feature MiFeature --api
```

Sigue los pasos manuales que imprime el comando (el `case` en
`Packages/Platform/Sources/Domain/AppRoute.swift`, el destino en `App/RootView.swift`, el
producto en `project.yml` si no hay marker `# archinit:products`), y complétalo con el
dominio real. `swift package archlint` (o el build de Xcode) te dice si te saliste de la
arquitectura — incluida la regla R13: una feature no puede importar otra.

### Reutilizar el Service/Store de otro feature (`--service-from`/`--store-from`)

`ProductDetail` reutiliza `ProductsServicing` (`Networking`) y `FavoritesStoring`
(`Domain`) — hecho a mano al mover la feature en la Fase 1 de la migración a modo multi.
Generado hoy, con el kit, sería:

```bash
cd Packages/Features
swift package --disable-sandbox --allow-writing-to-package-directory \
  generate-feature ProductDetail --api --local --service-from Products --store-from Favorites
```

Comprobado de verdad en este repo (generando `ProductDetailProbe`, revertido tras
capturar la evidencia — nunca llegó a compilar, no quedó en el árbol): el comando
funciona y da de alta el target, pero el test generado usa `ProductsServiceMock()`/
`FavoritesStoreMock()` directamente, sin `import PlatformTestSupport` — en ESTE repo esos
mocks viven en `PlatformTestSupport` (compartidos entre features, ver «Por qué dos
manifiestos SPM locales» y `docs/INFORME-MULTI.md`), no en `ProductsFeatureTests`/
`FavoritesFeatureTests` como el generador asume por defecto. El fichero generado no
compila hasta que, a mano, se añade `.product(name: "PlatformTestSupport", package:
"Platform")` a las `dependencies:` del test target nuevo en `Package.swift` y `import
PlatformTestSupport` al fichero de test. Repro completo y propuesta para 1.2.1 en
`docs/INFORME-MULTI.md` § «`--service-from`/`--store-from` en modo multi».

### Calidad de código: SwiftLint curado

Tres capas, cada una con su herramienta (PRD-AF-09):

| Capa | Herramienta | Valida |
|---|---|---|
| Arquitectura | `ArchitectureLint` (AppFoundation) | DÓNDE está el código: capas (R1-R12) y aislamiento entre módulos (R13) |
| Calidad | SwiftLint con `.swiftlint.yml` (raíz) | CÓMO está escrito: `try!`, casts y desempaquetados forzados, tamaños, complejidad, idioms |
| Concurrencia | el compilador (Swift 6, warnings estrictos) | Sendable, aislamiento, data races |

SwiftLint corre como build-tool plugin en `Packages/Platform/Package.swift` y
`Packages/Features/Package.swift`, junto a `ArchitectureLint`. CI lo corre también con
`--strict` sobre `Packages/Platform`/`Packages/Features`, y `swift format lint` con el
mismo `.swift-format` sobre `Packages`, `App`, `AppTests` y `AppUITests`.

## Arquitectura y sesión

- **`SessionStoring`/`UserDefaultsSessionStore`** (`Packages/Platform/Sources/Domain`):
  `UserDefaults`, no Keychain — elección deliberada del starter (la cosa más simple que
  funciona nada más clonar, sin provisionar Keychain access groups). Un fork de producción
  cambia `UserDefaultsSessionStore` por una implementación con Keychain detrás del MISMO
  protocolo; nada por encima cambia.
- **Refresh de token** (`Packages/Platform/Sources/Networking`): `NetworkingModule`
  construye dos `APIService` — uno sin interceptores para `/auth/login`/`/auth/refresh`
  (`AuthServicing`), y el autenticado que usan las demás features, con
  `BearerTokenInterceptor` + `TokenRefreshRetrier` (`NetworkingWiring.swift`). Un refresh
  fallido invalida la sesión y dispara `SessionExpiring` → `RootView` vuelve a `.login`
  con un banner.
- **`ArchitectureLint`**: activo como build-tool plugin en `Packages/Platform/Package.swift`
  y `Packages/Features/Package.swift` — cada build corre `archlint` sobre ese target. Ver
  «Criterios de aceptación» más abajo para la demostración de que un `import` entre
  features rompe el build (R13).

## Escaparate (PRD-APP-02)

Las dos tablas del PRD, fila por fila — tramo A (ya en el paquete único) y tramo B
(pantallas nuevas de esta fase), más las filas de tests que el PRD pide explícitamente.
Cada capacidad cita `` `Símbolo` en `fichero:línea` `` — verificable a ojo, y verificado
por máquina: `Scripts/check-showcase.sh` (`## CI`) comprueba que cada fichero exista y que
el símbolo aparezca de verdad a ±3 líneas de la citada.

### CoreNetworking

- **`APIService` + `NetworkingConfiguration`** (baseURL, decoder propio): construidos en
  `NetworkingConfiguration` en `Packages/Platform/Sources/Networking/NetworkingModule.swift:59`
  y `APIService` en `Packages/Platform/Sources/Networking/NetworkingModule.swift:62`; la
  configuración activa se muestra en `activeBaseURL` en
  `Packages/Features/Sources/SettingsFeature/SettingsView.swift:67`.
- **`BaseRequest` GET/POST con query, body y `Empty`**: GET con query en
  `GetProductsRequest` en `Packages/Features/Sources/ProductsFeature/Services/ProductsService.swift:8`
  (`queryItems` en la línea 49); POST con body en `LoginRequest` en
  `Packages/Platform/Sources/Networking/AuthService.swift:34`; POST de Uploads en
  `AddProductRequest` en `Packages/Features/Sources/UploadsFeature/Services/UploadsService.swift:18`;
  `Empty` en `Empty` en `Packages/Features/Sources/DiagnosticsFeature/Services/DiagnosticsService.swift:214`.
- **`APIError`**: categorías/código/resúmenes proyectados a `DiagnosticsOutcome` en
  `APIError` en `Packages/Features/Sources/DiagnosticsFeature/Services/DiagnosticsService.swift:233`
  (mapeo completo hasta la línea 245); `decodeBody` de un error del servidor y
  `LocalizedError` los ejercen los siete experimentos de Diagnostics contra ese mismo
  bloque.
- **`RequestInterceptor` + `RequestContext`**: `BearerTokenInterceptor` en
  `Packages/Platform/Sources/Networking/NetworkingWiring.swift:63`; `LoggingInterceptor`
  en `Packages/Features/Sources/DiagnosticsFeature/Services/DiagnosticsService.swift:158`;
  el interceptor propio (`X-Client` + contador) es `RequestCounterInterceptor` en
  `Packages/Features/Sources/DiagnosticsFeature/RequestCounterInterceptor.swift:19`, con
  `RequestContext` en la línea 30 y la cabecera `X-Client` en la línea 34 — su log se
  enseña en Diagnostics vía `diagnostics.log` en
  `Packages/Features/Sources/DiagnosticsFeature/DiagnosticsView.swift:72`.
- **`RequestRetrier` + `RetryPolicy`**: `RetryPolicy` en
  `Packages/Features/Sources/DiagnosticsFeature/Services/DiagnosticsService.swift:157`
  (el experimento `retry5xx`, reintentos visibles vía `RequestCounterInterceptor`).
- **`TokenRefresher` + `TokenRefreshRetrier`** (dedupe de refresh): `TokenRefresher` en
  `Packages/Platform/Sources/Networking/NetworkingWiring.swift:36`,
  `TokenRefreshRetrier` en `Packages/Platform/Sources/Networking/NetworkingWiring.swift:64`;
  probado con `ManualClock` en
  `Packages/Platform/Tests/NetworkingTests/NetworkingWiringTests.swift:71` (el 401→refresh→
  retry de un único caller — no hay, hoy, un segundo test que dispare DOS 401 concurrentes
  para probar el dedupe en sí; el mecanismo que lo garantiza es de `CoreNetworking`).
- **`EndpointService`**: `AuthService` en
  `Packages/Platform/Sources/Networking/AuthService.swift:97` (y `ProductsService` en
  `Packages/Features/Sources/ProductsFeature/Services/ProductsService.swift:91`).
- **`upload(_:data:progress:)` + `TransferProgress`**: `api.upload` en
  `Packages/Features/Sources/UploadsFeature/Services/UploadsService.swift:71`.
- **`SSLPinningConfiguration` + `PinningValidationResult`/`PinningFailure`**:
  `SSLPinningConfiguration` en
  `Packages/Platform/Sources/Networking/PinningPins.swift:31`; el toggle en
  `Packages/Features/Sources/SettingsFeature/SettingsView.swift:33`.
- **`HTTPTransport` propio + `InMemoryTransport`**: `InMemoryTransport` en
  `App/OfflineFixtures.swift:27`.
- **`ManualClock`, `MockAPIService`, `MockURLProtocol`, `RecordingInterceptor`**:
  `ManualClock` en
  `Packages/Platform/Tests/NetworkingTests/NetworkingWiringTests.swift:71`;
  `MockAPIService` en
  `Packages/Features/Tests/ProductsFeatureTests/Services/ProductsServiceTests.swift:15`.
  **No cubierto**: `MockURLProtocol` (el test de integración de este repo,
  `AuthIntegrationTests`, corre contra DummyJSON real, no contra `URLSessionTransport` con
  `MockURLProtocol`) y `RecordingInterceptor` (`RequestCounterInterceptor` — el
  interceptor propio de arriba — no tiene un test unitario dedicado que lo verifique con
  `RecordingInterceptor`; sus tres métodos (`willSend`/`didReceive`/`didFail`) solo se
  ejercen indirectamente vía `DiagnosticsUITests`/uso manual). Ambos, pendientes.
- **`TransportError`**: el host inalcanzable se mapea a `.unreachable` en
  `Packages/Features/Sources/DiagnosticsFeature/DiagnosticsModels.swift:121`
  (`DiagnosticsError.from(category:)` en la línea 144), disparado por
  `runUnreachable()` en
  `Packages/Features/Sources/DiagnosticsFeature/Services/DiagnosticsService.swift:180`.

### AppFoundation

- **`performLoad`/`performActivity`/`successTransition`/`load()`/`activity()`**:
  `performLoad` con `.preserveCurrentPhase` en
  `Packages/Features/Sources/ProductsFeature/ProductsViewModel.swift:63`; `activity()`
  estructurado con `.inline` en
  `Packages/Features/Sources/UploadsFeature/UploadsViewModel.swift:76`.
- **`ErrorPresenting` propio + `DomainError` + `isRetryable`**: `AppErrorPresenter` en
  `App/AppErrorPresenter.swift`; `isRetryable` en
  `Packages/Features/Sources/DiagnosticsFeature/DiagnosticsModels.swift:106`.
- **`CancellationRecognizing` + `inFlightLoad`**: cancelación manual en
  `Packages/Features/Sources/DiagnosticsFeature/DiagnosticsViewModel.swift:54`
  (`inFlightLoad?.cancel()`), verificada por `DiagnosticsUITests`.
- **`AlertState`** (destructiva): "Vaciar favoritos" en
  `Packages/Features/Sources/FavoritesFeature/FavoritesViewModel.swift:62`; logout en
  `Packages/Features/Sources/ProfileFeature/ProfileViewModel.swift:74`.
- **`BannerState`** (success/info/warning/error, `duration`): success de Uploads en
  `Packages/Features/Sources/UploadsFeature/UploadsViewModel.swift:81`; info de Settings
  en `Packages/Features/Sources/SettingsFeature/SettingsViewModel.swift:82`; el refresco
  fallido de Products (`performActivity` sin `errorHandling` explícito) en
  `Packages/Features/Sources/ProductsFeature/ProductsViewModel.swift:66` — el kit siempre
  muestra ESE banner en estilo `.error` (`BaseViewModel.handleActivityError`), no
  `.warning`: la descripción original de este PRD lo llamaba "warning", corregido aquí.
- **`ViewPhase`/`EmptyViewStyle`/`ErrorViewStyle`/`LoadingViewStyle`/`BannerViewStyle`**:
  los cuatro `Brand…Style` en `App/Theme/BrandLoadingStyle.swift`,
  `App/Theme/BrandErrorStyle.swift`, `App/Theme/BrandEmptyStyle.swift`,
  `App/Theme/BrandBannerStyle.swift`, instalados en `App/RootView.swift:48-51`; las 24
  capturas de `AppSnapshotTests` (más abajo) son las cuatro fases bajo ambos temas.
- **`ScreenChrome`/`NavigationBarStyle`/`NavigationBarItem`/`SearchBarConfiguration`**:
  `chrome: .custom` en
  `Packages/Features/Sources/ProductDetailFeature/ProductDetailView.swift:24`
  (`.stack` es el `placement` por defecto, no explícito ahí); en Gallery,
  `placement: .overlay` en
  `Packages/Features/Sources/GalleryFeatureUI/GalleryView.swift:31`, con
  `style: .transparent` en
  `Packages/Features/Sources/GalleryFeatureUI/GalleryView.swift:29`; `.blur` +
  `SearchBarConfiguration` en
  `Packages/Features/Sources/SearchFeature/SearchView.swift:27` (bar en la línea 32).
- **`PopGestureEnabler`** (swipe-back con barra custom): probado en
  `AppUITests/SwipeBackTests.swift:9` (ProductDetail) y
  `AppUITests/GalleryUITests.swift:9` (Gallery, `.overlay`).
- **`Coordinator`/`Router`/`CoordinatorView` + `DeepLink`**: `CoordinatorView` en
  `App/RootView.swift:69`; `DeepLinkType` en `App/DeepLink.swift:13`;
  `Coordinator.handle(_:as:map:)` en `App/DeepLink.swift:48`; probado offline en
  `AppUITests/DeepLinkUITests.swift:22,39`.
- **`Container`** (módulos, `lifecycle`, `Container(parent:)`): registro por defecto
  (singleton) en
  `Packages/Platform/Sources/Networking/NetworkingModule.swift:40`; `lifecycle:
  .transient` en
  `Packages/Features/Sources/DiagnosticsFeature/DiagnosticsModule.swift:32`;
  `Container(parent:)` por sesión en
  `Packages/Platform/Sources/Networking/AppSessionState.swift:95`, con el test de que un
  singleton de sesión no sobrevive al logout en
  `Packages/Platform/Tests/NetworkingTests/` (`AppSessionState — Container(parent:) per
  session`, ver `swift test --package-path Packages/Platform`).
- **`Debouncer`/`Throttler`**: `Debouncer` en
  `Packages/Features/Sources/SearchFeature/SearchViewModel.swift:37` (uso en la línea 57);
  `Throttler` en `Packages/Features/Sources/GalleryFeatureUI/GalleryViewModel.swift:31`
  (uso en la línea 60).
- **`Logic`/`LogicViewModel` + flags del generador**: `--api` en `LoginLogic` en
  `Packages/Features/Sources/LoginFeature/LoginLogic.swift:59`; `--local` en
  `FavoritesLogic` en `Packages/Features/Sources/FavoritesFeature/FavoritesLogic.swift:38`;
  `--api --local` + `--service-from`/`--store-from` (reutiliza `ProductsServicing` y
  `FavoritesStoring`): `favoritesStore` en
  `Packages/Features/Sources/ProductDetailFeature/ProductDetailModule.swift:17`; sin
  datos/`--local` (`UserDefaults` vía Store) en `UserDefaultsSettingsStore` en
  `Packages/Features/Sources/SettingsFeature/Stores/SettingsStore.swift:29`; `--module`
  (dos targets reales) en `GalleryFeatureUI/GalleryModule.swift:3` (`import
  GalleryFeatureCore`); `--api --no-service` (reutiliza `APIServiceProtocol` directo) en
  `Packages/Features/Sources/DiagnosticsFeature/Services/DiagnosticsService.swift:70`.
- **`AppFoundationTestSupport`**: `SpyRecorder` en
  `Packages/Features/Tests/ProductsFeatureTests/Mocks/ProductsLogicMock.swift:9`.
  **No cubierto**: `InMemoryStore` — los Stores de este repo (`FavoritesStore`,
  `SettingsStore`) tienen su propio doble en memoria hecho a mano
  (`Packages/Features/Tests/SettingsFeatureTests/Mocks/InMemorySettingsStore.swift`) en
  vez de `AppFoundationTestSupport.InMemoryStore`; pendiente para 1.2.2 o una
  refactorización de esos dos tests.
- **`L10n` + `.xcstrings` + `ResourceBundle`**: **no cubierto**. Este repo no tiene ningún
  `.xcstrings` ni usa `L10n`/`ResourceBundle` — todas las cadenas visibles son literales en
  español directamente en cada `View` (`"Diagnostics"`, `"Ajustes"`…). Localización real
  (es/en con `.xcstrings`) queda fuera de esta fase; hueco real, no un olvido de citarlo.
- **`AppFoundationDiagnostics`** (`droppedActionHandler`, `assertOnDroppedAction`): **no
  cubierto**. Ni `App/` activa `assertOnDroppedAction` en DEBUG ni hay un test que
  compruebe que un ViewModel liberado registra el descarte — el propio bug real que
  `docs/INFORME-MULTI.md` §11 documenta (un ViewModel vivo que no se re-renderizaba) es
  distinto de esto (un ViewModel ya LIBERADO cuyo trabajo pendiente se descarta). Hueco
  real.
- **`ObservingScreenState`/`BindingBackedState`/`PhaseView`/`ScreenModifier`**:
  `GalleryThumbnailsView` (sin ViewModel, `PhaseView` + `@State` local) en
  `Packages/Features/Sources/GalleryFeatureUI/GalleryView.swift:117` (declaración) y
  `:120` (uso).
- **`AppEnvironment`**: `Packages/Features/Sources/SettingsFeature/SettingsView.swift:61`
  (versión en la línea 62).
- **`CameraKit`/`AnalyticsAdapters` por protocolo de `Domain`**: `any CameraCapturing` en
  `Packages/Features/Sources/UploadsFeature/UploadsLogic.swift:76`;
  `recentEvents()` (`AnalyticsTracking`) en
  `Packages/Platform/Sources/Domain/AnalyticsTracking.swift:36`, consumido en
  `Packages/Features/Sources/SettingsFeature/SettingsLogic.swift:95`.
- **Linter R1–R14 + SwiftLint + Definition of Done**: `modules:` de R13 en
  `.archlint.yml:29`; una regla curada de SwiftLint (`try!` → error) en
  `.swiftlint.yml:12`; la demostración de un `import` entre features rompiendo el build
  con `[ArchLint.R13]` está en `docs/INFORME-MULTI.md`, no transcrita aparte en este
  README.

### Otras filas del tramo B (pantallas nuevas, ya en el paquete anterior a esta fase)

- `images: [URL]` (`Product`) en `Packages/Platform/Sources/Domain/Product.swift:18`.
- `case gallery(productID: Int)` en
  `Packages/Platform/Sources/Domain/AppRoute.swift:27`; `case settings` en
  `Packages/Platform/Sources/Domain/AppRoute.swift:38` (destino en
  `App/RootView.swift:108`).
- `CFBundleURLTypes:` fusionado en el Info.plist sintetizado en `project.yml:89`.
- `struct AppSettings` en `Packages/Platform/Sources/Networking/AppSettings.swift:17`
  (contrato compartido `Networking`↔`SettingsFeature`); `func loadSynchronously` en
  `Packages/Platform/Sources/Networking/AppSettings.swift:39`, usado en
  `AppSettings.loadSynchronously()` en
  `Packages/Platform/Sources/Networking/NetworkingModule.swift:54`.
  `ThemeSettings` (`@Observable`) en
  `Packages/Platform/Sources/Networking/ThemeSettings.swift:22`.
- `case untrustedServer` en
  `Packages/Features/Sources/DiagnosticsFeature/DiagnosticsModels.swift:104`.

### Pinning TLS: cómo se obtuvieron los pines reales

Dos pines reales de `dummyjson.com` — la hoja (rota en cada renovación) y la
intermediaria emisora (sobrevive a esa rotación, el "pin de respaldo" que pide
RFC 7469 §2.5):

```bash
openssl s_client -connect dummyjson.com:443 -servername dummyjson.com </dev/null \
  | openssl x509 -pubkey -noout \
  | openssl pkey -pubin -outform der \
  | openssl dgst -sha256 -binary | base64
```

```
leaf         (dummyjson.com):              q79YST4pUwa2CDkfrlOfH4rDdgrCXfQDLmtZeEBEk3w=
intermediate (Google Trust Services WE1):  kIdp6NNEd8wsugYyyIYFsi1ylMCED3hZbSR8ZFsa/A4=
```

El "pin falso" (`Packages/Platform/Sources/Networking/PinningPins.swift`) es base64
válido de 32 bytes (pasa la validación de forma de `SSLPinningConfiguration`) pero no
coincide con ninguna clave real — cualquier petición con él instalado falla
`.untrustedServer`, nunca `.cancelled` (`CoreNetworking`'s `TransportError`).

**El pinning se aplica en el PRÓXIMO lanzamiento, no en caliente.**
`NetworkingModule.register(in:)` lee `AppSettings` UNA VEZ, al registrar el
`Container`, para decidir si el `APIService` autenticado (y el de login/refresh) pinan
TLS — cada `*Service` ya resolvió y cacheó su propia referencia a `any
APIServiceProtocol` desde ese único registro; re-registrar el tipo después no llega a
ninguno de ellos. La comprobación manual de abajo reinicia la app entre tocar el
toggle y verificar su efecto.

## Tests

```bash
# Unitarios por capa (ViewModel/Logic/Service/Store), por paquete:
swift test --package-path Packages/Platform
swift test --package-path Packages/Features
swift package --package-path Packages/Platform archlint
swift package --package-path Packages/Features archlint
swiftlint lint --strict --quiet Packages/Platform/Sources Packages/Platform/Tests \
  Packages/Features/Sources Packages/Features/Tests
swift format lint --strict --configuration .swift-format --recursive \
  Packages App AppTests AppUITests AppSnapshotTests

# Integración real contra DummyJSON (login, productos, refresh con expiresInMins: 1):
INTEGRATION=1 swift test --package-path Packages/Features --filter AuthIntegrationTests

# El escaparate del README: cada `Símbolo` en `fichero:línea` existe de verdad.
Scripts/check-showcase.sh

# Nativos de Xcode — smoke test del composition root, AppSnapshotTests (24 capturas,
# PRD-APP-02 Fase 3) y los XCUITests offline, los tres desde el MISMO `xcodebuild test`
# (el esquema `AppStarter` corre `AppTests` + `AppSnapshotTests` + `AppUITests` en su
# acción `test`):
UI_TEST_OFFLINE=1 Scripts/bootstrap.sh
UI_TEST_OFFLINE=1 xcodebuild test -scheme AppStarter \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -skipPackagePluginValidation \
  -resultBundlePath TestResults.xcresult
```

Sin `UI_TEST_OFFLINE=1`, los XCUITests corren contra la API real (es el objetivo del
PRD); con esa variable, `-UITestOffline` hace que la app use `InMemoryTransport` con
respuestas grabadas (`App/OfflineFixtures.swift`) — así corre en CI sin depender de la
red.

### `AppSnapshotTests` — 24 capturas por estado y tema

`AppSnapshotTests/` (target nativo de Xcode, no un paquete SwiftPM — `swift-snapshot-
testing` renderiza a `UIImage` sobre `UIHostingController`, que necesita el runtime UIKit
real del simulador que ya arranca este esquema) captura `DiagnosticsView`/`UploadsView`/
`GalleryView` en `loading`/`empty`/`error`/`content`, con el `LoadingViewStyle`/
`ErrorViewStyle`/`EmptyViewStyle`/`BannerViewStyle` del kit y con los cuatro `Brand…Style`
de `App/Theme/` (`.snapshotTheme(_:)`, `AppSnapshotTests/SnapshotHelpers.swift`) — 3
pantallas × 4 estados × 2 temas = 24 imágenes. Los estados se inyectan por ViewModel/Logic
mock, sin red: `loading` siempre con `BaseViewModel.setLoading(_:)` directamente (evita la
carrera de esperar a un mock asíncrono); `empty`/`error`/`content` de `GalleryViewModel`
pasan por su `Logic` real vía un stub (`GalleryLogicProtocol`) porque esa pantalla SÍ los
alcanza en producción (`performLoad(successTransition: .preserveCurrentPhase)`); en
`Diagnostics`/`Uploads` (que nunca fallan su propio `appear()`) `empty`/`error` se inyectan
igual que `loading`, con `setEmpty()`/`setError(title:message:)` directos — el propio PRD
sanciona esto ("los estados se inyectan por ViewModel/Logic mock, sin red"). El tamaño de
cada captura se lee de `UIScreen.main.bounds` en tiempo de test (`snapshotDeviceSize`), no
un punto fijo — sigue siendo correcto sea cual sea el simulador del esquema. Referencias en
`AppSnapshotTests/__Snapshots__/` (versionadas): generadas y revisadas a ojo en este PR —
ver la descripción de cada una en `docs/INFORME-MULTI.md`, sección «`AppSnapshotTests` —
24 capturas...» del informe de Fase 3, bullet «Qué muestra cada captura».

Resultados literales de la última migración, y el detalle de cada fricción encontrada:
**`docs/INFORME-MULTI.md`** (modo multi) y **`docs/INFORME-INTEGRACION.md`** (integración
original de los paquetes desde Xcode).

## CI

`.github/workflows/ci.yml`, en cada push/PR a `main`:

- **`showcase`** (`ubuntu-latest`, no necesita Xcode): `Scripts/check-showcase.sh` — el
  primero en fallar si una fila del escaparate cita un `fichero:línea` que ya no existe.
- **`packages`** (matriz `Platform`/`Features`): `swift test` + `swift package archlint` +
  `swiftlint --strict` + `swift format lint`.
- **`app`** (depende de `packages`): `xcodegen generate` → `xcodebuild test` — el MISMO
  comando corre `AppTests` (smoke test), `AppSnapshotTests` (24 capturas) y `AppUITests`
  (offline), los tres targets del esquema `AppStarter`; `-resultBundlePath
  TestResults.xcresult`, subido como artefacto solo si el job falla (capturas y árbol de
  accesibilidad del runner, la única evidencia cuando el iOS del runner difiere del local).
- **`integration`** (real, contra DummyJSON): solo por `workflow_dispatch`.

Selección del Xcode más reciente disponible en el runner (`ls /Applications/Xcode_*.app`)
en cada job que lo necesita — nunca fijado a una versión concreta.

## Lo que hizo la IA

Honestidad sobre qué generó el kit (`archinit`/`generate-feature`/`archlint`) tal cual, qué
se completó a mano, y qué se descubrió en el camino — no todo lo de este repo salió de un
comando.

**Generado por el kit, sin tocar después:** el esqueleto de cada `View`/`ViewModel`/
`Logic`/`Module` (+ `Store` cuando tocaba) de las nueve features originales
(`generate-feature <Name> --api|--local|--api --local`), sus tests unitarios y mocks, la
estructura de tres niveles completa de `archinit --multi` (`App/`, `Packages/Platform`,
`Packages/Features`, `.archlint.yml` con `modules:`, `.swiftlint.yml`, `.swift-format`,
`project.yml`, `Scripts/bootstrap.sh`, `ci.yml` con la matriz por paquete), y `Gallery`
(`--api --module`, dos targets reales `GalleryFeatureCore`/`GalleryFeatureUI` en un solo
comando).

**Completado a mano, sobre lo generado:** el dominio real de cada `Logic` (mapeo de
`APIError`→`DomainError`, los siete experimentos de `Diagnostics`, la barra de progreso de
`Uploads`, el throttle de `Gallery`); todo el networking transversal
(`NetworkingWiring`/`AppSessionState`/`RefreshActivityLog`/`AppSettings`) porque no hay
generador para "código compartido por varias features"; los cuatro `Brand…Style` y su
instalación condicional en `RootView`; `App/DeepLink.swift` completo (el generador no sabe
de deep links); las 24 capturas de `AppSnapshotTests` y los nueve XCUITests offline; y el
propio contenido de este README, con cada fila del escaparate verificada por
`Scripts/check-showcase.sh`, no solo redactada.

**Bugs reales encontrados (no fricciones del kit — de esta app, o expuestos por ella)**,
cada uno con repro completo en `docs/INFORME-MULTI.md`:

- **La cookie que hacía pasar el 401 de Diagnostics.** `DiagnosticsService.unauthenticatedAPI`
  y `NetworkingModule`'s `AuthServicing` sin autenticar compartían `URLSessionTransport()`
  con `URLSessionConfiguration.default`, que acepta y reenvía cookies vía
  `HTTPCookieStorage.shared` — COMPARTIDO por todo el proceso. `POST /auth/login` de
  DummyJSON pone, además del par de tokens en el JSON, una cookie de sesión; tras un login
  real en el mismo proceso, esa cookie quedaba en el jar y la siguiente petición a
  `/auth/me` SIN cabecera `Authorization` la reenviaba sola — el experimento "401 sin
  token" devolvía 200. Arreglado con `httpShouldSetCookies = false`/
  `httpCookieAcceptPolicy = .never` en la configuración de ese pipeline (docs/
  INFORME-MULTI.md, «Dos hallazgos reales al ejecutar Diagnostics contra DummyJSON»).
- **`waitsForConnectivity = true`** (el valor correcto para el pipeline real de la app, que
  SÍ debe esperar a que vuelva la red) hacía que el experimento "host inalcanzable" se
  quedara colgado más de 75s en vez de fallar rápido por DNS — una `URLSessionConfiguration`
  propia con `waitsForConnectivity = false` para ESE transporte lo arregló, sin tocar el
  pipeline real.
- **El stall del semáforo de `DiagnosticsService.init`** (docs/INFORME-MULTI.md §7): copiar
  literalmente el patrón `DispatchSemaphore` de `App/OfflineFixtures.swift` (seguro SOLO
  durante el arranque, antes de que haya UI/eventos) a un singleton que se construye
  PEREZOSAMENTE, la primera vez que se navega a Diagnostics — en mitad de una transición de
  navegación de SwiftUI, compitiendo por el mismo hilo que el `Task` necesita — colgaba el
  primer "Run" de un experimento ~60s. Arreglado registrando el fixture de forma async
  normal (sin semáforo) al principio de `runRetry5xx()`, no en el `init`.
- **`generate-feature Uploads --api` registrando su PROPIO `APIServiceProtocol`**
  (docs/INFORME-MULTI.md §8): `UploadsModule.register(in:)`, tal cual lo generó el kit,
  registraba un `APIServiceProtocol` nuevo y sin autenticar — `Container.register`
  sobrescribe silenciosamente cualquier registro anterior del MISMO tipo, así que cualquier
  feature registrada DESPUÉS de `UploadsModule` en `AppModule.makeModules()` habría perdido
  su bearer token, sin error de compilación, solo un aviso de consola en DEBUG fácil de
  pasar por alto. Arreglado quitando ese registro: `UploadsService` resuelve el
  `APIServiceProtocol` autenticado YA existente de `NetworkingModule`, como todo lo demás.
- **`@Observable` no se hereda de `BaseViewModel`** (docs/INFORME-MULTI.md §11): el hallazgo
  más caro de esta fase — ver la sección de arriba sobre AppFoundation 1.2.1/R15, que ya lo
  corrige en el kit.
- **`SIGSEGV`/`SIGBUS` por un `.build/` incremental desactualizado** (docs/INFORME-MULTI.md
  §12): tras varios commits que fueron cambiando el layout de `AppRoute` (un tipo
  compartido, nuevos casos con valores asociados), `swift test --package-path
  Packages/Features` crasheaba el binario combinado de tests de forma consistente — sitio
  de fallo distinto cada vez, siempre corrupción de memoria, nunca un fallo de aserción
  normal, confirmado por bisección real que el mismo checkout pasa 100% de las veces con
  `rm -rf Packages/Features/.build` primero y crashea 100% de las veces sin ese paso. No es
  una fricción de `AppFoundation`/`CoreNetworking` — es SwiftPM y su build incremental para
  un paquete con varios test targets ante un tipo `Domain` compartido; el workaround es
  simplemente borrar `.build/` antes de una tanda de verificación importante.

**Fricciones del kit, abiertas:** `PRD-AF-11` (en el monorepo del kit, no en este repo) —
`--service-from`/`--store-from` en modo multi asume que los mocks compartidos viven en el
propio test target de la feature, no en un target `PlatformTestSupport` separado (ver
«Reutilizar el Service/Store de otro feature» más arriba); y la doble coincidencia de R13
con nombres de frameworks del sistema (`UIKit` contra el glob `*Kit`, `docs/INFORME-MULTI.md`
§10). Ambas viven como propuestas en `docs/ISSUES.md`, no arregladas aquí — no es este
repo quien las corrige, es el kit.

## Licencia

MIT.
