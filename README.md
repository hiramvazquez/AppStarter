# AppStarter

Una app iOS real — login, catálogo de productos, detalle, favoritos y perfil — que
consume [`AppFoundation`](https://github.com/hiramvazquez/AppFoundation) y
[`CoreNetworking`](https://github.com/hiramvazquez/CoreNetworking) 1.0.0 contra la API
pública [DummyJSON](https://dummyjson.com). Es la plantilla de arranque: clónala, cambia
el dominio y las pantallas, y ya tienes la arquitectura, el generador y el linter
funcionando desde el primer commit.

## Qué es

- **Proyecto**: [xcodegen](https://github.com/yonaskolb/XcodeGen) genera
  `AppStarter.xcodeproj` desde `project.yml` — el `.xcodeproj` no se versiona.
- **Arquitectura**: View → ViewModel → Logic → Services/Stores (la de `AppFoundation`),
  sin excepciones, con `ArchitectureLint` activo en el build.
- **Cinco pantallas + una hoja modal**: Login, Productos (lista paginada), Detalle de
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

```
AppStarter/                    proyecto xcodegen
├── project.yml                 targets, esquema, dependencias SPM
├── Scripts/bootstrap.sh        xcodegen generate
├── AppStarter/                 target de la app — cáscara fina
│   ├── AppStarterApp.swift      @main: registra los DependencyModule, instala AppErrorPresenter
│   ├── RootView.swift           CoordinatorView + switch sobre AppRoute
│   └── OfflineFixtures.swift    InMemoryTransport con respuestas grabadas (-UITestOffline)
├── AppStarterTests/            unit test nativo de Xcode — smoke test del composition root
├── AppStarterUITests/          los 4 XCUITests del PRD
├── AppStarterKit/               ← paquete local SPM: TODA la lógica de negocio y sus tests
│   ├── Package.swift            depende de AppFoundation/CoreNetworking 1.0.0 (remoto)
│   ├── .archlint.yml, AGENTS.md, .claude/skills/feature.md   (de `archinit`)
│   ├── Sources/AppStarterKit/
│   │   ├── Core/                 AppRoute, SessionStore, AppSessionState, CoreModule, NetworkingWiring
│   │   └── Features/             Login, Products, ProductDetail, Favorites, Profile, Search
│   └── Tests/AppStarterKitTests/ unit tests por capa + el test de integración real
└── docs/
    ├── INFORME-INTEGRACION.md   fricciones al integrar los paquetes desde Xcode
    └── ISSUES.md                issues propuestas para AppFoundation/CoreNetworking
```

### Por qué un paquete local (`AppStarterKit`) en vez de solo un `.xcodeproj`

`generate-feature`/`archinit`/`archlint` son **command plugins de SwiftPM**: necesitan un
`Package.swift` real sobre el que invocarse. Un `.xcodeproj` de xcodegen no lo ofrece por
sí solo. `AppStarterKit` es ese paquete: contiene todas las Features y sus tests: el
target `AppStarter` (la app) es una cáscara fina que solo resuelve `ViewModel`s desde
`Container.shared` y monta la navegación. `swift build`/`swift test` funcionan
directamente dentro de `AppStarterKit/`, sin abrir Xcode — así es como se usó el
generador y el linter de verdad (ver más abajo). Detalle completo en
`docs/INFORME-INTEGRACION.md`, fricción 1.

## El kit, usado de verdad

Cada comando de abajo se ejecutó tal cual, dentro de `AppStarterKit/`, y su salida real
(recortada) está en `docs/INFORME-INTEGRACION.md`.

```bash
# Una vez, al principio del proyecto:
swift package --allow-writing-to-package-directory archinit
# → .archlint.yml, Features/, AGENTS.md, CLAUDE.md, .claude/skills/feature.md

# Una vez por feature:
swift package --allow-writing-to-package-directory generate-feature Login --api
swift package --allow-writing-to-package-directory generate-feature Products --api
swift package --allow-writing-to-package-directory generate-feature ProductDetail --api --local
swift package --allow-writing-to-package-directory generate-feature Favorites --local
swift package --allow-writing-to-package-directory generate-feature Profile --api
swift package --allow-writing-to-package-directory generate-feature Search --api
```

Cada `generate-feature` escribió el cascarón completo (View/ViewModel/Logic/Service o
Store/Module + tests + mocks) **compilando y en verde desde el primer segundo** — el
`swift build && swift test` inmediatamente después de los seis comandos pasó sin tocar
nada. A partir de ahí completé cada feature a mano: el dominio real (DummyJSON, no
`LoginItem` genérico), las llamadas HTTP reales, y — en `ProductDetail`/`Search` — sustituí
el `Service` generado por defecto por una dependencia a `ProductsServicing` (compartido
con `Products`), porque el generador siempre crea un Service nuevo por feature y no sabe
reutilizar uno existente (fricción 3 del informe).

### Añadir una feature nueva

```bash
cd AppStarterKit
swift package --allow-writing-to-package-directory generate-feature MiFeature --api
```

Sigue los "pasos manuales" que imprime el comando (añadir el `case` a `AppRoute`,
registrar el `DependencyModule` en `AppStarterApp.makeModules()`), y complétalo con el
dominio real. `swift package archlint` (o el build de Xcode, que ya lo
corre solo) te dice si te saliste de la arquitectura.

### Calidad de código: SwiftLint curado

Tres capas, cada una con su herramienta (PRD-AF-09 del kit, calibrado aquí primero):

| Capa | Herramienta | Valida |
|---|---|---|
| Arquitectura | `ArchitectureLint` (AppFoundation) | DÓNDE está el código: capas, nombres, `APIError` fuera del ViewModel (R1-R12) |
| Calidad | SwiftLint con `AppStarterKit/.swiftlint.yml` | CÓMO está escrito: `try!`, casts y desempaquetados forzados, `[unowned]`, tamaños, complejidad, idioms |
| Concurrencia | el compilador (Swift 6, warnings estrictos) | Sendable, aislamiento, data races |

SwiftLint corre como build-tool plugin en `AppStarterKit/Package.swift`, junto a
`ArchitectureLint`: un `try!` en un ViewModel rompe el build con un error navegable en
Xcode (`error: Force Try Violation … (force_try)`), igual que una violación de capa. Las
reglas de tamaño y de idioms son avisos en Xcode y solo bloquean en CI (`swiftlint
--strict`). La configuración usa `only_rules` (una versión nueva de SwiftLint no activa
reglas sin que lo decidamos) y cada regla lleva su porqué; las descartadas en la
calibración están anotadas con el motivo. Detalle en `docs/INFORME-CALIDAD.md`.

El formato lo pone `swift-format` con el mismo `.swift-format` que los paquetes del kit
(`swift format format -i --recursive AppStarterKit/Sources AppStarterKit/Tests`).

## Arquitectura y sesión

- **`SessionStore`**: `UserDefaults`, no Keychain — elección deliberada del starter (la
  cosa más simple que funciona nada más clonar, sin provisionar Keychain access groups).
  Un fork de producción cambia `UserDefaultsSessionStore` por una implementación con
  Keychain detrás del MISMO protocolo `SessionStoring`; nada por encima cambia.
- **Refresh de token**: `CoreModule` construye dos `APIService` — uno sin interceptores
  para `/auth/login`/`/auth/refresh` (`AuthService`), y el autenticado que usan las demás
  features, con `BearerTokenInterceptor` + `TokenRefreshRetrier` (`Core/NetworkingWiring.swift`).
  Un refresh fallido invalida la sesión y dispara `SessionExpiring` → `RootView` vuelve a
  `.login` con un banner.
- **`ArchitectureLint`**: activo como build-tool plugin en `AppStarterKit/Package.swift`
  — cada build de Xcode lo corre. Ver "Criterios de aceptación" más abajo para la
  demostración de que una violación rompe el build.

## Tests

```bash
# Unitarios por capa (ViewModel/Logic/Service/Store), dentro del paquete:
cd AppStarterKit && swift test

# Integración real contra DummyJSON (login, productos, refresh con expiresInMins: 1):
cd AppStarterKit && INTEGRATION=1 swift test --filter AuthIntegrationTests

# Nativos de Xcode — smoke test del composition root + los 4 XCUITests, offline:
UI_TEST_OFFLINE=1 xcodebuild -scheme AppStarter \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -skipPackagePluginValidation test
```

Sin `UI_TEST_OFFLINE=1`, los XCUITests corren contra la API real (es el objetivo del
PRD); con esa variable, `-UITestOffline` hace que la app use `InMemoryTransport` con
respuestas grabadas (`AppStarter/OfflineFixtures.swift`) — así corre en CI sin depender
de la red.

Resultados literales de la última ejecución, y el detalle de cada fricción encontrada:
**`docs/INFORME-INTEGRACION.md`**.

## CI

`.github/workflows/ci.yml`: `xcodegen generate` → `swift package archlint`
→ `swiftlint --strict` + `swift format lint` → `swift test` (AppStarterKit) → `xcodebuild test` (unit + UI, offline) en cada
push/PR a `main`. Job `integration` (real, contra DummyJSON) solo por
`workflow_dispatch`.

## Licencia

MIT.
