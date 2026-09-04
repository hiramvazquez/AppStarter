# AppStarter

Una app iOS real — login, catálogo de productos, detalle, favoritos y perfil — que
consume [`AppFoundation`](https://github.com/hiramvazquez/AppFoundation) 1.2.0 y
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

## Escaparate (PRD-APP-02, tramo B)

Cada fila, verificable en el código real — `fichero:línea`:

| Capacidad | Dónde |
|---|---|
| `Product.images` (`GET /products/{id}` trae varias imágenes) | `Packages/Platform/Sources/Domain/Product.swift:18` |
| `ScreenChrome.custom(_, placement: .overlay)` + `NavigationBarStyle.transparent` | `Packages/Features/Sources/GalleryFeatureUI/GalleryView.swift:24` (estilo en la línea 30) |
| `Throttler` (prefetch de la siguiente imagen, clock inyectable) | `Packages/Features/Sources/GalleryFeatureUI/GalleryViewModel.swift:31,60` |
| `PhaseView` + estado local sin ViewModel (miniaturas) | `Packages/Features/Sources/GalleryFeatureUI/GalleryView.swift:112,120` |
| `AppRoute.gallery(productID:)` desde `ProductDetail` | `Packages/Platform/Sources/Domain/AppRoute.swift:27` |
| `DeepLinkType` (`appstarter://product/<id>`, `appstarter://search?q=<query>`) | `App/DeepLink.swift:13,21` |
| `Coordinator.handle(_:as:map:)` — `.setStack`/`.present` desde un deep link | `App/DeepLink.swift:48` |
| `CFBundleURLTypes` fusionado en el Info.plist sintetizado (xcodegen `info.properties`) | `project.yml:84` |
| `SearchBarConfiguration` en barra custom `.blur` | `Packages/Features/Sources/SearchFeature/SearchView.swift:27,32` |
| `Debouncer` (texto de búsqueda, clock inyectable) | `Packages/Features/Sources/SearchFeature/SearchViewModel.swift:31,57` |
| `AppSettings` (contrato compartido `Networking`↔`SettingsFeature`) | `Packages/Platform/Sources/Networking/AppSettings.swift` |
| `AppSettings.loadSynchronously(from:)` — bootstrap síncrono para `NetworkingModule` | `Packages/Platform/Sources/Networking/AppSettings.swift:39`, usado en `Packages/Platform/Sources/Networking/NetworkingModule.swift:54` |
| `SSLPinningConfiguration` (pines reales + pin falso) | `Packages/Platform/Sources/Networking/PinningPins.swift:31` |
| `UserDefaultsSettingsStore` (actor + conformidad en extension) | `Packages/Features/Sources/SettingsFeature/Stores/SettingsStore.swift:29` |
| `AnalyticsTracking.recentEvents()` mostrados en Settings | `Packages/Platform/Sources/Domain/AnalyticsTracking.swift:36`, consumido en `Packages/Features/Sources/SettingsFeature/SettingsLogic.swift:95` |
| `AppEnvironment` (debug/release, versión) | `Packages/Features/Sources/SettingsFeature/SettingsView.swift:61-62` |
| `ThemeSettings` (`@Observable`, broadcast en vivo) | `Packages/Platform/Sources/Networking/ThemeSettings.swift:22` |
| Los cuatro `Brand…Style` instalados en `RootView` | `App/Theme/Brand*.swift`, instalados en `App/RootView.swift:41-44` |
| `AppRoute.settings` desde `Profile` | `Packages/Platform/Sources/Domain/AppRoute.swift:38`, destino en `App/RootView.swift:90` |
| `APIError.Category.untrustedServer` → `DiagnosticsError.untrustedServer` | `Packages/Features/Sources/DiagnosticsFeature/DiagnosticsModels.swift` |

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

# Integración real contra DummyJSON (login, productos, refresh con expiresInMins: 1):
INTEGRATION=1 swift test --package-path Packages/Features --filter AuthIntegrationTests

# Nativos de Xcode — smoke test del composition root + los 4 XCUITests, offline:
UI_TEST_OFFLINE=1 Scripts/bootstrap.sh
UI_TEST_OFFLINE=1 xcodebuild test -scheme AppStarter \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -skipPackagePluginValidation
```

Sin `UI_TEST_OFFLINE=1`, los XCUITests corren contra la API real (es el objetivo del
PRD); con esa variable, `-UITestOffline` hace que la app use `InMemoryTransport` con
respuestas grabadas (`App/OfflineFixtures.swift`) — así corre en CI sin depender de la
red.

Resultados literales de la última migración, y el detalle de cada fricción encontrada:
**`docs/INFORME-MULTI.md`** (modo multi) y **`docs/INFORME-INTEGRACION.md`** (integración
original de los paquetes desde Xcode).

## CI

`.github/workflows/ci.yml`: matriz `packages` (`Platform`/`Features`: `swift test` +
`swift package archlint` + `swiftlint --strict` + `swift format lint`) → job `app`
(`xcodegen generate` → `xcodebuild test`, unit + UI offline) en cada push/PR a `main`. Job
`integration` (real, contra DummyJSON) solo por `workflow_dispatch`.

## Licencia

MIT.
