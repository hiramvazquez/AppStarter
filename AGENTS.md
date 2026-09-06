# AppStarter — guía para agentes

Arquitectura obligatoria de cualquier feature: **View → ViewModel → Logic → Services/Stores**.
Un `Logic` por `ViewModel`. Todo entra por `init`, siempre como protocolo. Nada de esto
llama a `Container.shared`/`@Inject` por su cuenta: el composition root es el `XxxModule`.
Estructura **modular de tres niveles** (`archinit --multi`, PRD-AF-10): `App/` (cáscara),
`Packages/Platform` (Domain/Networking/Kits/Adapters) y `Packages/Features` (un target real
por feature) — nunca un paquete por feature, y nunca lógica de negocio dentro de `App/`.

## Cómo se trabaja aquí: el kit

Este proyecto usa **[ios-agent-kit](https://github.com/hiramvazquez/ios-agent-kit)**, un
plugin de Claude Code. Los agentes, comandos, hooks y scripts **no viven en este repo**:
los pone el plugin. Aquí dentro solo hay dos cosas suyas, y las dos son nuestras:

| | |
|---|---|
| `openspec/` | nuestras specs, cambios activos y archivados |
| `kit.conf` | 10 líneas: qué verifica este proyecto y dónde vive el código |

**Para trabajar en este repo necesitas instalarlo una vez:**

```bash
npm install -g @fission-ai/openspec@latest
claude plugin marketplace add hiramvazquez/ios-agent-kit
claude plugin install ios-agent-kit@hiram-kits -y
```

**El bucle:**

```
/opsx:propose "…"   →  se acuerda, sin tocar código
/opsx:apply         →  se implementa
/kit-verifica       →  build + tests de los dos paquetes, firmado contra el diff
   reviewer         →  ¿esto rompe algo?
/kit-acepta         →  ¿es lo acordado?
/opsx:archive       →  el delta se funde en openspec/specs/
```

No se commitea sin firma de verificación válida: la puerta de `PreToolUse` lo bloquea.
Stagea, verifica y commitea en **comandos separados** — encadenar `git add && git commit`
cambia el diff entre la firma y el commit.

Las reglas de Swift/SwiftUI las trae el plugin (`swift-swiftui`, SwiftAgents adaptado a
iOS 17, que es nuestro deployment target). **Donde discrepen con este AGENTS.md, gana este
AGENTS.md**: la arquitectura de este repo manda sobre cualquier guía general.

Documentación completa del kit: [instalación](https://github.com/hiramvazquez/ios-agent-kit/blob/main/docs/INSTALACION.md)
· [primer cambio](https://github.com/hiramvazquez/ios-agent-kit/blob/main/docs/PRIMER-CAMBIO.md)
· [las piezas](https://github.com/hiramvazquez/ios-agent-kit/blob/main/docs/PIEZAS.md)

## Módulos de este proyecto

| Módulo | Dónde | Puede importar | Nunca importa |
|---|---|---|---|
| `Domain` | `Packages/Platform/Sources/Domain` | Foundation | nada más (`Product`, `UserProfile`, `StoredSession`/`SessionStoring`, `FavoritesStoring`, `AppRoute`) |
| `Networking` | `Packages/Platform/Sources/Networking` | Foundation, AppFoundation, CoreNetworking, Domain | `*Feature`, `*Kit`, `*Adapters` (`AuthServicing`/`ProductsServicing`, `AppSessionState`/`SessionExpiring`, `RefreshActivityLog`, `NetworkingModule`) |
| `CameraKit` | `Packages/Platform/Sources/CameraKit` | Foundation, Domain | `*Feature`, `*Adapters`, `Analytics*` (stub; Fase 2 lo usa de verdad) |
| `AnalyticsAdapters` | `Packages/Platform/Sources/AnalyticsAdapters` | Foundation, Domain, `Analytics*` | `*Feature`, `*Kit` (stub de consola; Fase 2) |
| `PlatformTestSupport` | `Packages/Platform/Sources/PlatformTestSupport` | Foundation, Domain, Networking, CoreNetworking, AppFoundationTestSupport | — (mocks/spies compartidos por más de un `*FeatureTests`) |
| `<Name>Feature` | `Packages/Features/Sources/<Name>Feature` | Foundation, SwiftUI, Observation, SwiftData, AppFoundation, CoreNetworking, Domain, Networking | `*Feature`, `*Kit`, `*Adapters`, `Analytics*` (las features se comunican por `Domain` y por `AppRoute`, nunca importándose entre sí) |
| App (`App/`) | target de xcodegen, no un producto SPM | todo | lógica de negocio (solo composición: `AppModule`/`RootView`/`AppErrorPresenter`/`OfflineFixtures`) |

Estas reglas las aplica `ArchitectureLint` R13 (aislamiento entre módulos) vía la sección
`modules:` de `.archlint.yml` (raíz del repo) — un `import` prohibido rompe `swift build`
con `[ArchLint.R13]`, no solo el code review. `AppRoute` vive en `Domain`, no en
`App/AppRoute.swift` (donde lo deja `archinit --multi` para un proyecto sin features
todavía): toda feature navega a otras pantallas por `Router<AppRoute>`/
`Coordinator<AppRoute>`, y una feature no puede importar `App` — ver
`docs/INFORME-MULTI.md` para el porqué completo y la fricción que esto expone en el kit.

## Si vas a añadir una feature nueva

```bash
cd Packages/Features
swift package --allow-writing-to-package-directory generate-feature MiFeature --api
```

En modo multi (marcador `.archinit-multi` en `Packages/Features/`), `generate-feature` da
de alta el target real (y su test target) entre los markers `archinit:features-*`/
`archinit:products-*` de `Packages/Features/Package.swift`, y añade el `import`/módulo en
`App/AppModule.swift` (marker `// archinit:modules`) — best-effort, igual que el `case` de
`App/AppRoute.swift`, que en este repo no existe (ver arriba): añade el `case` a
`Packages/Platform/Sources/Domain/AppRoute.swift` a mano, y el destino en
`App/RootView.swift` (el generador siempre imprime este último paso, en modo multi o no).

## Capas

- **View** (SwiftUI): recibe el `ViewModel`, renderiza con `ScreenContainer(vm) { send in … }`.
  Nunca importa `CoreNetworking`, nunca referencia `*Logic`/`*Service`/`*Store`. La View es
  dueña de su ViewModel con `@State private var viewModel: XxxViewModel` +
  `_viewModel = State(initialValue: viewModel)` en el `init` — nunca `let viewModel:`
  (R12 avisa si se te olvida; un ViewModel transitorio con `let` se libera a mitad de un
  push de navegación).
- **ViewModel** (`@MainActor`): `final class XxxViewModel: LogicViewModel<any XxxLogicProtocol>,
  ActionHandling`. Orquesta: recibe `Action` en `handle(_:)`, llama a `logic`, actualiza
  `phase`/estado propio, decide navegación (`Router`/`Coordinator`). Nunca conoce
  `APIService`, `URLSession`, SwiftData ni un `*Service`/`*Store` concreto — solo `logic`.
- **Logic** (`nonisolated`, métodos `async`): `protocol XxxLogicProtocol: Logic { … }` +
  `final class XxxLogic: XxxLogicProtocol`. TODA la lógica de negocio; traduce el error del
  Service/Store (`APIError`, SwiftData) a un error de dominio propio (`XxxError: DomainError`)
  ANTES de devolverlo — el ViewModel y el `ErrorPresenting` nunca ven `APIError`. Sin
  `import SwiftUI`/`UIKit`. Sin referencias a `*ViewModel`/`Router`/`Coordinator`.
  Dependencias por `init` como `any XxxServicing`/`any XxxStoring` — declarados en la propia
  feature si nadie más los necesita (`ProfileServicing`), o en `Networking`/`Domain` si los
  comparten varias (`ProductsServicing`, `FavoritesStoring`).
- **Service** (API, `struct Sendable`): `protocol XxxServicing: Sendable` + una
  implementación que es la ÚNICA que toca `APIServiceProtocol`/`BaseRequest` y que devuelve
  MODELOS DE DOMINIO (nunca el DTO/`Response` decodificado). Un Service = una llamada a API
  con su propio `BaseRequest`. Conformar `EndpointService` (`CoreNetworking`) da `call(_:)`
  gratis.
- **Store** (local, `actor`/`@ModelActor` con SwiftData): `protocol XxxStoring` + una
  implementación que es la ÚNICA que toca SwiftData/CoreData/UserDefaults/Keychain/
  FileManager, y que igualmente devuelve modelos de dominio. Misma forma que un Service,
  distinto origen.

## Piezas de este proyecto (por encima de `AppFoundation`)

- `Product`/`ProductsPage`/`UserProfile`/`StoredSession` (`Domain`): el vocabulario
  compartido — nunca un DTO de red ni un `@Model` de SwiftData.
- `AuthServicing`/`ProductsServicing` (`Networking`): protocolos compartidos por más de una
  feature; sus implementaciones concretas (`AuthService`, `ProductsService`) viven donde se
  construyen — `AuthService` en `Networking` (lo construye `NetworkingModule`),
  `ProductsService` en `ProductsFeature` (lo construye `ProductsModule`, el único que lo
  necesita).
- `NetworkingModule` (`Networking`): registra `SessionStoring`, `AppSessionState`/
  `SessionExpiring`, `RefreshActivityLog`, `AuthServicing`, y el `APIServiceProtocol`
  autenticado. `PlatformModule` (`App/AppModule.swift`) registra la navegación
  (`Coordinator<AppRoute>`/`Router<AppRoute>`) y los Kits/Adapters — no lo dupliques aquí.

## Cómo testear cada capa

- **ViewModel**: `XxxLogicMock: XxxLogicProtocol` (spy) → `viewModel.handle(.acción)` →
  `await viewModel.inFlightLoad?.value` → assert sobre `phase`/propiedades observables.
- **Logic**: `XxxServiceMock`/`XxxStoreMock` (o `InMemoryStore`) → llama al método del
  `Logic` directamente; incluye un test por cada mapeo de error a `DomainError`. Los mocks
  compartidos por más de un feature (`SessionStoreSpy`, `ProductsServiceMock`,
  `FavoritesStoreMock`…) viven en `PlatformTestSupport`, no duplicados en cada
  `*FeatureTests`.
- **Service**: `MockAPIService` (stub por tipo de request) para el caso feliz/error, e
  `InMemoryTransport` para el pipeline real (retries, interceptores, refresh de token —
  `Packages/Platform/Tests/NetworkingTests`).
- **Store**: `InMemoryStore`/`InMemoryXxxStore` en tests; SwiftData con `ModelContainer`
  en memoria (`isStoredInMemoryOnly: true`) solo en el test del Store real.

## Qué NO hacer

- No inyectes un tipo concreto de Service/Store/Logic en otra capa — siempre `any XxxProtocol`.
- No dejes que `APIError`/un error de SwiftData llegue al ViewModel: mapéalo a `DomainError`
  dentro del `Logic`.
- No pongas lógica de negocio ni navegación en el `ViewModel`/`Logic` respectivamente.
- No llames a `Container.shared`/`@Inject` desde ViewModel/Logic/Service/Store: regístralos
  y resuélvelos desde el `XxxModule` (composition root).
- No importes una feature desde otra (`import ProductsFeature` dentro de `SearchFeature`):
  R13 rompe el build. Si necesitas datos de otra feature, recibe un protocolo de `Domain`/
  `Networking` por `init`; si necesitas navegar a su pantalla, usa `AppRoute`.

## Generador y linter

```bash
cd Packages/Features
swift package --allow-writing-to-package-directory generate-feature Login --api      # Service
swift package --allow-writing-to-package-directory generate-feature Notes --local    # Store (SwiftData)
swift package --allow-writing-to-package-directory generate-feature Catalog --api --local
swift package --allow-writing-to-package-directory generate-feature Counter          # sin datos
```

Genera View/ViewModel/Logic/Service/Module (+ Store si toca) + tests/mocks, todo
compilando y en verde. En modo multi, da de alta el target en `Package.swift` — el resto de
pasos manuales (arriba, «Si vas a añadir una feature nueva»), imprímelos y hazlos tú.

`ArchitectureLint` (build-tool plugin, en `Packages/Platform/Package.swift` y
`Packages/Features/Package.swift`) y `swift package archlint --path <paquete>` (command
plugin, para CI o una comprobación puntual) aplican las reglas R1-R14 — un error de build
es lo único que no se puede ignorar. Antes de escribir código de una capa a mano, repasa la
tabla de reglas en el artículo `Lint` de `Documentation.docc` de AppFoundation: importar
`CoreNetworking` fuera de Logic/Service (R1/R7), dejar que un `APIError`/DTO llegue al
ViewModel (R7/R8), llamar a `Container.shared` fuera del `XxxModule` (R10), o importar una
feature desde otra (R13) hacen fallar el build, no solo el code review.

Ver también: `README.md` (arranque y estructura), `docs/INFORME-MULTI.md` (la migración a
modo multi y sus fricciones), `docs/INFORME-INTEGRACION.md` (integración original de los
paquetes desde Xcode) y `Sources/AppFoundation/Documentation.docc/` del propio
`AppFoundation` (`MultiModule`, `Generator`, `Lint`) para la referencia completa del kit.
