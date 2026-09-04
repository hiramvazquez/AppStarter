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
- **Seis pantallas + una hoja modal**: Login, Productos (lista paginada), Detalle de
  producto (favorito ⭐, `chrome: .custom` a propósito), Favoritos (SwiftData), Perfil
  (`GET /auth/me`, logout, y muestra cuándo se renovó el token en silencio), Buscar
  (sheet).
- **Sesión**: bearer token + refresh automático en 401, con logout global si el refresh
  también falla.

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
│   ├── AppStarterApp.swift        @main: instala AppErrorPresenter, registra AppModule.makeModules()
│   ├── AppModule.swift            composition root: PlatformModule (navegación, CameraKit, AnalyticsAdapters)
│   │                              + NetworkingModule + los seis módulos de feature
│   ├── RootView.swift             CoordinatorView + switch sobre AppRoute (Domain)
│   ├── AppErrorPresenter.swift    mapeo DomainError → ScreenError, instalado en @main
│   └── OfflineFixtures.swift      InMemoryTransport con respuestas grabadas (-UITestOffline)
├── AppTests/                     smoke test nativo de Xcode del composition root completo
├── AppUITests/                   los 4 XCUITests del PRD + el helper de arranque compartido
├── Packages/
│   ├── Platform/                  1 Package.swift — Domain, Networking, CameraKit, AnalyticsAdapters
│   │   ├── Sources/Domain/          modelos y protocolos compartidos: Product, UserProfile,
│   │   │                            StoredSession/SessionStoring, FavoritesStoring, AppRoute
│   │   │                            — SOLO importa Foundation
│   │   ├── Sources/Networking/      lo que necesita CoreNetworking pero es transversal a
│   │   │                            varias features: AuthServicing/ProductsServicing,
│   │   │                            AppSessionState/SessionExpiring, RefreshActivityLog,
│   │   │                            NetworkingWiring.swift, NetworkingModule
│   │   ├── Sources/CameraKit/       stub de CameraProviding (Fase 2 lo usa de verdad)
│   │   ├── Sources/AnalyticsAdapters/  stub de AnalyticsAdapting (consola; Fase 2)
│   │   └── Sources/PlatformTestSupport/  mocks/spies compartidos por más de un *FeatureTests
│   │                                     (SessionStoreSpy, ProductsServiceMock, FavoritesStoreMock…)
│   └── Features/                  1 Package.swift — un target <Name>Feature por feature
│       ├── Sources/LoginFeature/ ProductsFeature/ ProductDetailFeature/ FavoritesFeature/
│       │                         ProfileFeature/ SearchFeature/  (View/ViewModel/Logic/Module
│       │                                                          + Services/Stores propios)
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
