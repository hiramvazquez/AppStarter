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

**Y con qué toolchain se construye:** con el que trae el Xcode instalado, no con otro. Si
tienes swiftly (o cualquier gestor que deje un `swift` propio en el PATH) apuntando a una
versión anterior a la de Xcode, el build muere así:

```
error: build planning stopped due to build-tool plugin failures
<unknown>:0: error: unknown argument: '-target-arch-variant'
```

Ninguno de los dos mensajes nombra el toolchain: el frontend antiguo no entiende los flags
que emite el SwiftPM de Xcode, y su PluginAPI no puede cargar `BuildToolPlugin`, así que
`ArchitectureLint` ni arranca y no se compila una sola línea. Parece un fallo del repo y no
lo es. Compruébalo antes de mirar el código —`swift --version` contra `xcrun swift --version`,
tienen que coincidir— y si divergen:

```bash
swiftly use --global-default xcode
```

**Y el CI valida con otro Xcode que el tuyo.** Aquí se desarrolla con Xcode 27 / Swift 6.4;
el CI fija **Xcode 26.3 / Swift 6.2.4** en el `env:` de `.github/workflows/ci.yml`
(`XCODE_SOPORTADO`). Una verificación local en verde —`/kit-verifica` incluido— **no prueba**
que el CI vaya a pasar: medido el 2026-09-17, el diagnóstico `[#IsolatedConformances]` sobre
una conformidad inferida como aislada al MainActor es error en Swift 6.2.4 y no lo es en 6.4.
Si el CI rechaza algo que en tu máquina compila, se corrige el código para que compile en las
dos; subir la versión del CI es una decisión del owner, no la salida por defecto. El sentido
contrario —código que solo acepta 26.3— lo vigila el job `aviso-toolchain-desarrollo`, que
corre en Xcode 27 y no bloquea.

**El bucle:**

```
/opsx:propose "…"   →  se acuerda, sin tocar código
/opsx:apply         →  se implementa
/kit-verifica       →  build + tests de los dos paquetes, firmado contra el árbol y el índice
/kit-revisa         →  ¿esto rompe algo?   ← el obligatorio antes de archivar
/kit-acepta         →  ¿es lo acordado?    ← OPCIONAL
/opsx:archive       →  el delta se funde en openspec/specs/
```

El único paso opcional es el juez: se invoca **cuando nadie vaya a leer el acuerdo contra lo
entregado** —cambios grandes o que tocan varias capas (más de unos cinco ficheros), alcance que
se movió al implementar, o cuando quien orquesta no es quien acordó—.

No se commitea sin firma de verificación válida: lo bloquea la puerta de commit, un hook
`pre-commit` de git que `/kit-verifica` deja instalado en cada firma.
Stagea, verifica y commitea en **comandos separados** — se firma el árbol **y** el índice, así
que encadenar `git add && git commit` cambia el índice entre la firma y el commit. Y un
`git commit -am` sobre un árbol editado después de firmar también queda bloqueado: antes se
colaba.

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

En modo multi (marcador `.archinit-multi` en `Packages/Features/`), y comprobado con
AppFoundation 1.4.2, `generate-feature` registra él mismo —cada cosa, si encuentra su marker—:

- en `Packages/Features/Package.swift`, el target real y su test target entre los markers
  `archinit:features-begin`/`-end`, y el producto entre `archinit:products-begin`/`-end`;
- el `import` en `App/AppModule.swift` y en `App/RootView.swift` (marker `// archinit:imports`
  en los dos);
- el módulo en `App/AppModule.swift` (marker `// archinit:modules`);
- el destino `case .<nombre>:` en `App/RootView.swift` (marker `// archinit:destinations`);
- el producto en `project.yml` (marker `# archinit:products`).

Quedan dos pasos a mano:

1. Añade `case <nombre>` a `Packages/Platform/Sources/Domain/AppRoute.swift`. Sin él la app no
   compila, porque el destino que acaba de añadir el generador referencia `AppRoute.<nombre>`.
   Ojo: el generador pide este paso nombrando `App/AppRoute.swift`, que en este repo no existe
   (ver arriba).
2. `xcodegen generate` —o `Scripts/bootstrap.sh`, que lo ejecuta— para que el target nuevo entre
   en el proyecto de Xcode.

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

## Seguridad: lo que se da por hecho

Seis invariantes. No son consejos: cada uno tiene detrás una comprobación que corre en
`/kit-verifica`, así que incumplir uno deja el proyecto **sin firma** y la puerta bloquea el
commit. El detalle y sus escenarios están en la spec `seguridad`.

Con una excepción que conviene conocer: la firma **no cubre `openspec/`**, así que un secreto
escrito ahí después de verificar no invalida la firma y ese commit pasa. Lo caza la siguiente
verificación, porque el escaneo sí mira ese directorio. Para los otros cinco invariantes no
aplica: solo miran Swift, y en `openspec/` no hay Swift.

| se da por hecho | lo comprueba |
|---|---|
| No hay secretos en el árbol | `gitleaks`, con `.gitleaks.toml` |
| Nada imprime a consola en producción | SwiftLint `no_print_in_production` |
| Ningún log expone valores con `privacy: .public` | SwiftLint `os_log_public_interpolation` |
| Ninguna URL de red usa `http://` | SwiftLint `no_http_url` |
| Las credenciales no viven en `UserDefaults` | SwiftLint `sesion_fuera_de_keychain` |
| No hay `try!`, `as!` ni `!` forzado | SwiftLint `force_try`, `force_cast`, `force_unwrapping` |
| ATS no está desactivado | el paso `ATS`, sobre `project.yml` y los `Info.plist` |

Dos cosas que conviene saber antes de escribir:

- **Un secreto commiteado no se arregla borrando la línea**: queda en la historia y hay que
  rotarlo. Por eso el escaneo va antes del commit y no después.
- **La única excepción declarada** es `UserDefaultsSessionStore`
  (`Packages/Platform/Sources/Domain/Session.swift`), que guarda el bearer token en
  `UserDefaults` por la decisión de plantilla de PRD-APP-01. Está escrita en
  `.swiftlint.yml`, junto a la regla que la detecta. Un segundo almacén de credenciales sobre
  `UserDefaults` falla, y así debe ser.

Lo que estas comprobaciones **no** miran: si una autorización está bien puesta, si esa
pantalla debería ver esos datos, o qué se envía a terceros. Eso no se decide leyendo el texto
del código, y es trabajo del revisor (`/kit-revisa`).

Y son de texto, no de semántica: el almacén de credenciales se detecta por el NOMBRE del
fichero, así que uno llamado de otra forma se escapa; una URL construida por concatenación, o
escrita dentro de un string multilínea, también. Y un `.gitleaksignore` en la raíz puede
tapar un hallazgo de secretos: si aparece uno, que diga por qué.

Lo de ATS se comprueba en los dos sitios donde se desactiva hoy: `project.yml`, que es la
fuente que fusiona xcodegen, y CUALQUIER plist del árbol —da igual cómo se llame y aunque no
esté stageado todavía, porque el build lee el disco y no el índice—. El plist se lee con
`plutil`, que entiende el formato binario en el que Xcode los reescribe a veces, y si no se
puede leer el paso falla: no se puede afirmar que esté limpio algo que no se ha mirado. Se
vigila la clave `NSAppTransportSecurity` entera, porque todas sus variantes abren el mismo
agujero. Queda fuera un `xcconfig`, que hoy este proyecto no tiene.

Las dependencias se revisan contra vulnerabilidades conocidas en el CI, no en cada commit: lo
que cambia ahí no es este repositorio, son los avisos publicados.

## Generador y linter

```bash
cd Packages/Features
swift package --allow-writing-to-package-directory generate-feature Login --api      # Service
swift package --allow-writing-to-package-directory generate-feature Notes --local    # Store (SwiftData)
swift package --allow-writing-to-package-directory generate-feature Catalog --api --local
swift package --allow-writing-to-package-directory generate-feature Counter          # sin datos
```

Genera View/ViewModel/Logic/Service/Module (+ Store si toca) + tests/mocks, todo
compilando y en verde. En modo multi, da de alta el target en `Package.swift` y registra la
feature en la app; los dos pasos que quedan a mano están arriba, en «Si vas a añadir una
feature nueva».

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
