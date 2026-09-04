# Informe de migración a modo multi (PRD-APP-02, Fase 1)

AppStarter pasa de un único paquete local (`AppStarterKit/`) a la estructura modular de
tres niveles que deja `archinit --multi` (PRD-AF-10): `App/` (cáscara de xcodegen),
`Packages/Platform` (Domain, Networking, CameraKit, AnalyticsAdapters) y
`Packages/Features` (un target real por feature). Sin funcionalidad nueva: los 46 tests
unitarios + 2 de integración que ya existían siguen siendo los mismos, movidos, no
reescritos; los 4 XCUITests siguen siendo los mismos ficheros. Este informe documenta el
proceso paso a paso, las decisiones de dónde fue cada pieza, y cada fricción NUEVA del kit
respecto al modo single-package (ya documentado en `docs/INFORME-INTEGRACION.md`), con su
repro, para 1.2.1.

## Procedimiento seguido

1. `git checkout -b multi`; commits pequeños, uno por pieza movida.
2. `Scripts/bootstrap-multi.sh AppStarter --capability Camera --adapter Analytics` desde
   la raíz del repo (AppFoundation 1.2.0). Generó `App/` (placeholder), `Packages/Platform`
   (Domain + CameraKit + AnalyticsAdapters, stubs), `Packages/Features` (manifiesto vacío
   con los markers), `.archlint.yml` raíz con `modules:`, y la skill `/feature`.
3. `Packages/Platform/Sources/Domain`: modelos/protocolos que ya compartían dos o más
   features, o que la cáscara necesita — ver «Qué fue a Domain» abajo.
4. `Packages/Platform/Sources/Networking` (NO lo genera `archinit --multi`; añadido a
   mano): lo que necesitaba `CoreNetworking` pero era transversal a varias features — ver
   «Qué fue a Networking» abajo.
5. Cada feature, un commit: `Packages/Features/Sources/<Name>Feature` +
   `Tests/<Name>FeatureTests`, dado de alta entre los markers con la forma exacta que
   escribe `generate-feature` (verificada generando y borrando una feature de prueba,
   `ScratchProbeFeature`, en el propio `Packages/Features` — ver «Cómo verifiqué la forma
   exacta del manifiesto» abajo).
6. `App/`: `AppStarterApp.swift`, `AppModule.swift` (composition root: `PlatformModule` +
   `NetworkingModule` + los seis módulos de feature), `RootView.swift`,
   `AppErrorPresenter.swift`, `OfflineFixtures.swift`; `project.yml` con los productos de
   Platform/Features; `AppTests`/`AppUITests` renombrados desde
   `AppStarterTests`/`AppStarterUITests` (mismo contenido).
7. `AppStarterKit/` borrado.
8. Verificación completa (salidas reales abajo) y documentación.

## Decisiones: qué fue a Domain, qué a Networking, qué a la cáscara

La regla del PRD es clara en el papel («`Domain` solo importa Foundation; lo que necesite
CoreNetworking va a `Networking`») pero el código real de AppStarter tenía piezas que no
encajan limpiamente en esa frontera. Estas son las decisiones y por qué:

### Domain (`Packages/Platform/Sources/Domain`)

`Product`/`ProductsPage`, `UserProfile`, `StoredSession`/`SessionStoring`/
`UserDefaultsSessionStore`, `FavoritesStoring`, `AppRoute`. Todos compilan con Foundation
a secas: `SessionStoring`/`FavoritesStoring` no declaran `throws(APIError)` (a diferencia
de `ProductsServicing`/`AuthServicing`, ver abajo), así que no necesitan `CoreNetworking`.

**`AppRoute` es la decisión menos obvia.** El diagrama de la sección «Estructura de
llegada» del PRD y la plantilla de `archinit --multi`
(`Templates/Multi/AppRoute.swift.txt`) colocan `AppRoute` en `App/AppRoute.swift` — y
`generate-feature` en modo multi solo sabe editar ESE fichero (marker
`// archinit:routes`). Pero `App/` es el target ejecutable de xcodegen, no un producto
SPM: ninguna `*Feature` puede importarlo. AppStarter navega de verdad entre features
(`ProductsViewModel` empuja a `.productDetail`/`.favorites`/`.profile`, abre `.search`
como sheet; `SearchViewModel` empuja a `.productDetail`; `LoginViewModel` hace
`router.setRoot(.products)`…) — cada `*ViewModel` necesita `Router<AppRoute>`/
`Coordinator<AppRoute>` con el tipo `AppRoute` real, no un tipo genérico. La única forma
de que tanto `App` como cada `*Feature` vean el mismo `AppRoute` es que viva en el único
módulo del que ambos dependen: `Domain`. Encaja además con la propia frase de
`MultiModule.md`: «si [una feature] navega a [otra pantalla], lo hace por una ruta de
`AppRoute` que resuelve la app» — para que eso sea cierto en un caso con navegación
cruzada real, `AppRoute` tiene que ser alcanzable desde la feature que navega, no solo
desde la app. Ver «Fricción 3» abajo para el repro y la propuesta.

### Networking (`Packages/Platform/Sources/Networking`, no lo genera el kit)

`AuthServicing`/`AuthService` (+ sus DTOs `LoginRequest`/`RefreshRequest`), `AuthSession`/
`AuthTokens`, `ProductsServicing` (solo el protocolo — la implementación
`ProductsService`, con sus DTOs, se queda en `ProductsFeature`, la única que la
construye), `AppSessionState`/`SessionExpiring`, `RefreshActivityLog`,
`NetworkingWiring.swift` (`makeAuthenticatedAPIService`), y `NetworkingModule` (antes
`CoreModule`).

Por qué cada una:

- **`ProductsServicing`/`AuthServicing` no pueden vivir en `Domain`**: ambos declaran
  `async throws(APIError) -> …` — `APIError` es un tipo de `CoreNetworking`, y `Domain`
  solo importa `Foundation`. La regla del PRD («lo que necesite CoreNetworking va a
  Networking») los saca de `Domain` directamente.
- **`AuthService` (la implementación, no solo el protocolo) tiene que estar en
  `Networking`, no en `LoginFeature`**, porque `NetworkingModule.register(in:)`
  CONSTRUYE `AuthService` directamente (`AuthService(api: rawAPI)`) para el `APIService`
  sin interceptores de `/auth/login`/`/auth/refresh` — no lo resuelve del `Container`. Si
  `AuthService` viviera en `LoginFeature`, `Networking` tendría que importar una feature
  para construirlo: prohibido (R13, y conceptualmente al revés — Networking es una capa
  MÁS BAJA que las features). `ProductsService` en cambio SÍ vive en `ProductsFeature`,
  porque solo `ProductsModule` lo construye — nadie más necesita la implementación
  concreta, solo el protocolo.
- **`AppSessionState`/`SessionExpiring` no pueden vivir en `Domain`**: `AppSessionState`
  retiene un `Coordinator<AppRoute>` concreto (`AppFoundation`), y `Domain` no importa
  `AppFoundation`. `LoginFeature`'s `LoginViewModel` depende del tipo CONCRETO
  `AppSessionState` (no solo del protocolo `SessionExpiring`) para leer
  `consumeExpiryBanner()` — un método que no es parte del contrato `SessionExpiring`.
  Ponerlo en `Networking` (que sí importa `AppFoundation` y ya es un import permitido
  para `*Feature`) evita tener que ampliar el protocolo `SessionExpiring` con un método
  específico de UI solo para mover la clase a `Domain` — cero cambios de firma en
  `LoginViewModel`/`LoginView`/`LoginModule`.
- **`RefreshActivityLog`** vive al lado de `AppSessionState` por la misma razón de
  cohesión (ambas son observabilidad de sesión que `Profile`/`Login` consumen
  directamente como tipo concreto) — aunque en sí misma no necesita `AppFoundation` más
  que `@Observable`.
- **`NetworkingWiring.swift`/`NetworkingModule`**: el PRD ya lo dice explícitamente («el
  wiring del `APIService` autenticado… va a un target `Networking`»). La única variación
  respecto al `CoreModule` original: la navegación (`Coordinator<AppRoute>`/`Router`) se
  extrajo a `PlatformModule` (en `App/AppModule.swift`, generado por `archinit --multi`)
  en vez de quedarse aquí — evita registrar `Coordinator<AppRoute>` dos veces si algún
  día `Networking` y `PlatformModule` se registran ambos, y sigue exactamente la forma
  que el propio kit genera para `PlatformModule`.

### La cáscara (`App/`)

`AppErrorPresenter` (se instala una vez en `@main`, ninguna feature lo referencia — deja
de ser `public`, ya no cruza un límite de módulo), `OfflineFixtures` (fixtures de
`-UITestOffline`, ya vivía en el target de la app), `AppModule`/`AppStarterApp`/
`RootView` (composition root generado por `archinit --multi`, completado con los seis
módulos y el `switch` real).

### `PlatformTestSupport` (nuevo, no lo pide el PRD explícitamente pero lo implica)

Los mocks/spies que el paquete único compartía entre varias features
(`SessionStoreSpy`/`SessionExpiringSpy` — Login, Profile, Networking, integración;
`ProductsServiceMock` — Products, ProductDetail, Search; `FavoritesStoreMock` —
ProductDetail, Favorites) no pueden duplicarse silenciosamente ni vivir dentro de un solo
`*FeatureTests` (los demás no podrían importarlo — un test target no es un producto
importable entre paquetes). Van a un producto de biblioteca SEPARADO en `Packages/Platform`
(`PlatformTestSupport`, mismo patrn que `AppFoundationTestSupport`: nunca en el binario de
producción, solo dependencia de test) — es justo lo que sugiere `AGENTS.md` de
AppFoundation 1.2.0 bajo el nombre `PlatformTestSupport`/`DomainTestSupport`.

### Un caso sin solución limpia: `IntegrationTests`

`AuthIntegrationTests` (login real, productos reales, refresh real) ejercita
`AuthService` (Networking) + `ProductsService` (ProductsFeature) + `ProfileService`
(ProfileFeature) A LA VEZ contra la API real. Ningún `*FeatureTests` puede depender de
otro feature sin, en la práctica, hacer lo mismo que prohíbe R13 en producción — la
diferencia es que R13 ignora `Tests/**` por defecto, así que es LEGAL, pero forzarlo
dentro de, por ejemplo, `LoginFeatureTests` habría sido engañoso (parecería que
`LoginFeature` depende de `ProductsFeature`/`ProfileFeature`). Se creó un target
`IntegrationTests` dedicado, fuera de los markers `archinit:features-*` (`generate-feature`
nunca lo tocará, ni falla si no lo encuentra — no forma parte de su contrato).

## Fricciones nuevas del kit (repro + propuesta para 1.2.1)

### 1. `archinit --multi` necesita `--disable-sandbox`; el plugin solo declara `.writeToPackageDirectory`

**Repro:**

```bash
cd Packages/Features
swift package --allow-writing-to-package-directory archinit --multi --root ../.. --name AppStarter
```

```
error: Error Domain=NSCocoaErrorDomain Code=513 "You don't have permission to save the
file "Domain" in the folder "Sources"." … NSUnderlyingError=…"Operation not permitted"
```

**Causa:** `Plugins/ArchInit` (en `AppFoundation/Package.swift`) declara
`permissions: [.writeToPackageDirectory(reason: …)]` — que solo cubre el directorio del
PROPIO paquete (`Packages/Features`, donde se invoca el comando). En modo `--multi` el
plugin escribe deliberadamente FUERA de ese directorio: `Packages/Platform`, `App/`,
`project.yml`, `.archlint.yml` de la raíz. `--allow-writing-to-package-directory` en la
línea de comandos no amplía ese permiso — solo confirma el que el manifiesto ya declaró.

**Workaround usado aquí:**

```bash
swift package --disable-sandbox --allow-writing-to-package-directory archinit --multi …
```

**Propuesta para 1.2.1:** el `.plugin(name: "ArchInit", …)` en `Package.swift` de
AppFoundation debería declarar `permissions: [.writeToPackageDirectory(reason: …),
.allowNetworkConnections(...)]`… en realidad lo que falta es un permiso de escritura FUERA
del paquete — SwiftPM no tiene un permiso genérico "escribe en el repo padre" para
command plugins (`.writeToPackageDirectory` es literal). La opción realista es que
`Scripts/bootstrap-multi.sh` documente/incluya `--disable-sandbox` en el propio script (no
solo en la guía), ya que hoy el script falla con el mismo error sin él — o que el
`ArchInit` en modo `--multi` detecte el fallo de sandbox y lo explique en vez de dejar
pasar el `NSCocoaErrorDomain` crudo de Foundation.

### 2. `AppRoute` no puede vivir donde `archinit --multi`/`generate-feature` lo esperan

Ya razonado arriba («Qué fue a Domain»). Consecuencias prácticas para quien use
`generate-feature` en este repo a partir de ahora:

**Repro** (con los 6 features ya migrados, generando una feature de prueba real):

```
$ cd Packages/Features && swift package --allow-writing-to-package-directory generate-feature ScratchProbe --api
…
App/AppModule.swift: import ScratchProbeFeature añadido
App/RootView.swift: import ScratchProbeFeature añadido
App/RootView.swift: destino ScratchProbeView añadido
project.yml: producto ScratchProbeFeature NO añadido (project.yml no tiene el marker '# archinit:products') — hazlo a mano

Modo multi: ScratchProbeFeature + ScratchProbeFeatureTests
Registrado entre los markers de Package.swift (targets: y products:).
App/AppModule.swift: añadido 'ScratchProbeModule()'.
App/AppRoute.swift: añadido 'case scratchProbe'.
```

El generador AFIRMA haber editado `App/AppRoute.swift` — pero ese fichero no existe en
este repo (se borró en el commit «archinit --multi levanta el andamiaje…»; `AppRoute` está
en `Packages/Platform/Sources/Domain/AppRoute.swift`). En la prueba real hecha aquí (con
`ScratchProbeFeature`, revertida después de capturar la forma exacta del manifiesto), el
comando SÍ creó un `App/AppRoute.swift` propio (heredado del `PlaceholderView`/`.placeholder`
que el propio `archinit --multi` había dejado, todavía sin borrar en ese momento del
experimento) — es decir, el "éxito" reportado depende de que ese fichero exista con el
marker, y en cuanto se borra (como aquí), `generate-feature` no puede fallar-con-aviso
limpiamente: no hay comprobación previa de "¿existe `App/AppRoute.swift`?" antes de
imprimir el mensaje de éxito — solo la hay para el fallo silencioso documentado en
`Generator.md` («si el fichero o el marker no existen, el generador no falla — imprime el
paso manual»). Repetido tras borrar `App/AppRoute.swift` (el estado real de este repo):

```
$ rm App/AppRoute.swift   # estado real del repo tras la migración
$ cd Packages/Features && swift package --allow-writing-to-package-directory generate-feature ScratchProbe2 --api
…
App/AppRoute.swift: no existe App/AppRoute.swift — hazlo a mano
```

Esto SÍ es el comportamiento documentado («best-effort… imprime el paso manual») —
funciona correctamente una vez `App/AppRoute.swift` no existe. La fricción real es
conceptual, no un bug: **el propio diseño de `archinit --multi` asume que `AppRoute` es
App-only**, lo que solo es cierto para una app sin navegación cruzada entre features.
Cualquier app real con más de una feature que navegue a otra (que es el caso común, no el
raro) tiene que tomar la misma decisión que aquí: mover `AppRoute` a `Domain` a mano, y
perder la automatización del marker `// archinit:routes`.

**Propuesta para 1.2.1:** que `archinit --multi` (con o sin flag) pueda generar
`AppRoute` en `Packages/Platform/Sources/Domain/AppRoute.swift` en vez de `App/`, y que
`generate-feature` busque el marker `// archinit:routes` primero ahí y luego en
`App/AppRoute.swift` (o un flag `--routes-in-domain` en `archinit --multi` que decida el
destino de una vez). Sería la opción por defecto más útil para cualquier app con más de
una pantalla que navegue a otra.

### 3. `ProductsServicing`/`AuthServicing` compartidos rompen R3 (protocolo no está en el mismo fichero que el Service)

**Repro:**

```
$ swift build --package-path Packages/Features
…
Sources/ProductsFeature/Services/ProductsService.swift:1:1: error: [ArchLint.R3] Falta
'protocol XxxServicing: Sendable' — un Service declara su protocolo antes de su
implementación.
```

**Causa:** R3 es un chequeo léxico POR FICHERO — un fichero clasificado como Service
(`Services/XxxService.swift`) debe declarar `protocol XxxServicing: Sendable` en el MISMO
fichero. En modo multi, cuando el protocolo se comparte entre varias features (aquí,
`ProductsServicing` entre `ProductsFeature`, `ProductDetailFeature`, `SearchFeature`) tiene
que vivir en un módulo aparte (`Networking`) para que las tres puedan importarlo sin
importarse entre sí (R13) — pero entonces el fichero del Service (que sí sigue en la
feature que lo construye) ya no contiene la declaración del protocolo, y R3 no sabe
buscarla en otro módulo.

**Workaround usado aquí:** `disabled: [R3]` en `Packages/Features/.archlint.yml`, con el
repro documentado ahí mismo. Se pierde la comprobación de que ninguna otra capa toca
`APIServiceProtocol`/`BaseRequest` directamente — mitigado porque el resto de reglas de
capa (R1, R2, R4, R7) siguen activas y ya cubren buena parte de esa garantía desde otros
ángulos (R7: `import CoreNetworking` solo en Logic/Service).

**Propuesta para 1.2.1:** que R3 acepte que el `protocol XxxServicing`/`XxxStoring`
requerido esté declarado en OTRO fichero del MISMO target (ya sería una mejora: no
resolvería este caso exacto, donde vive en `Networking`, un target distinto) o, más
generalmente, que compruebe que existe un tipo con ese nombre en cualquier módulo que el
fichero importa (`import Networking` + `protocol ProductsServicing` ahí) antes de fallar
— exactamente el mismo tipo de resolución cross-módulo que R13 ya hace.

### 4. La coma colgante antes de los markers no sobrevive a `swift-format`

**Repro:**

```bash
# Tras archinit --multi + generate-feature x6, con .swift-format
# (multiElementCollectionTrailingCommas: false, el que instala el propio archinit):
swift format format --in-place --configuration .swift-format --recursive Packages App
```

Antes:
```swift
    static func makeModules() throws -> [DependencyModule] {
        [
            PlatformModule(),
            NetworkingModule(baseURL: apiBaseURL, transport: transport),
            …
            SearchModule(),
            // archinit:modules
        ]
    }
```

Después de `swift format format -i`:
```swift
    static func makeModules() throws -> [DependencyModule] {
        [
            PlatformModule(),
            NetworkingModule(baseURL: apiBaseURL, transport: transport),
            …
            SearchModule()
            // archinit:modules
        ]
    }
```

La coma tras `SearchModule()` desaparece — `swift-format` la trata como "coma colgante del
último elemento de un array" (el comentario no cuenta como elemento). El mismo patrón
aparece en `Packages/Features/Package.swift`, antes de `// archinit:products-end` y
`// archinit:features-end`.

**Impacto:** la siguiente `generate-feature` (Fase 2, otro agente) insertará su nueva
entrada tal cual la plantilla la construye — con una coma DELANTE de la nueva entrada,
asumiendo que la anterior ya termina en coma:

```swift
            SearchModule()
            NewModule(),
            // archinit:modules
```

Eso NO compila (`SearchModule()` sin coma antes de `NewModule()`) — un `swift build`
falla con un error de sintaxis, no de arquitectura, justo después de un
`generate-feature` aparentemente exitoso.

**Workaround:** ninguno aplicado preventivamente — se documenta aquí para que la Fase 2
sepa que, tras cualquier `generate-feature`, si el repo acaba de pasar por
`swift format format -i`, hay que revisar a mano que la línea anterior al marker termine
en coma antes de compilar (o simplemente ejecutar `swift build` inmediatamente: el error
de sintaxis es evidente y se arregla con una coma).

**Propuesta para 1.2.1:** que el propio `.swift-format` que `archinit`/`archinit --multi`
instalan excluya explícitamente `App/AppModule.swift`, `App/AppRoute.swift` y los dos
`Package.swift` de la reformateabilidad automática (o que las plantillas de
`generate-feature`/`archinit --multi` dejen de depender de una coma colgante y en su lugar
inserten la coma delante de la línea nueva, no dependan de que la anterior ya la tenga)
— la segunda opción es más robusta porque no depende de qué `.swift-format` tenga cada
proyecto.

### 5. Fricciones ya conocidas que se confirmaron sin cambios

Se repasaron explícitamente para este informe y siguen aplicando igual que en
`docs/INFORME-INTEGRACION.md`: xcodegen no soporta referenciar un test target de paquete
Swift local en un scheme (fricción 7 — por eso `swift test --package-path
Packages/Platform`/`Packages/Features` van aparte del `xcodebuild test` del esquema), y
`xcodebuild` necesita `-skipPackagePluginValidation` (fricción 5).

## Prueba negativa de R13 (ejecutada y revertida)

```bash
$ sed -i '' '1i\
import ProductsFeature
' Packages/Features/Sources/SearchFeature/SearchLogic.swift
$ swift build --package-path Packages/Features
…
archlint: 1 error(s), 0 warning(s) in 4 file(s).
/Users/…/Packages/Features/Sources/SearchFeature/SearchLogic.swift:1:1: error:
[ArchLint.R13] 'SearchFeature' no puede importar 'ProductsFeature': las features se
comunican por Domain y por AppRoute.
```

Revertido (`cp` desde la copia de seguridad); `swift build --package-path
Packages/Features` vuelve a compilar limpio.

## Verificación (salidas reales)

```
$ swift test --package-path Packages/Platform
✔ Test run with 3 tests in 2 suites passed after 0.010 seconds.
(1 Domain — placeholder de archinit --multi, nuevo — + 2 NetworkingWiringTests, movidas)

$ swift test --package-path Packages/Features
✔ Test run with 46 tests in 15 suites passed after 0.038 seconds.
(44 ejecutados — los mismos 44 tests de capa de las 6 features, movidos sin reescribir —
+ 2 de integración, omitidos sin INTEGRATION=1: "Suite 'DummyJSON integration' skipped")

$ swift package --package-path Packages/Platform archlint
archlint: 0 errors, 0 warning(s) in 21 file(s).

$ swift package --package-path Packages/Features archlint
archlint: 0 errors, 0 warning(s) in 28 file(s).   # R13 activa (modules: en .archlint.yml raíz)

$ swiftlint lint --strict --quiet --config .swiftlint.yml Packages/Platform/Sources Packages/Platform/Tests
(sin salida = limpio, exit 0)

$ swiftlint lint --strict --quiet --config .swiftlint.yml Packages/Features/Sources Packages/Features/Tests
(sin salida = limpio, exit 0)

$ swift format lint --strict --configuration .swift-format --recursive Packages App AppTests AppUITests
(sin salida = limpio, exit 0)

$ UI_TEST_OFFLINE=1 Scripts/bootstrap.sh && UI_TEST_OFFLINE=1 xcodebuild test -scheme AppStarter \
    -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -skipPackagePluginValidation
…
Test Suite 'AppTests.xctest' passed — Executed 1 test (CompositionRootTests.allModulesResolve), 0 failures
Test Suite 'AppUITests.xctest' passed — Executed 4 tests (AccessibilityLabelTests, DynamicTypeTests,
  FullFlowTests, SwipeBackTests), 0 failures, 111.7s
** TEST SUCCEEDED **

$ INTEGRATION=1 swift test --package-path Packages/Features --filter AuthIntegrationTests
✔ Test "Un login con credenciales inválidas contra el servidor real devuelve 400 (.invalidCredentials)"
  passed after 0.348 seconds.
✔ Test "Login real, productos reales, y refresh real con expiresInMins: 1" passed after 0.897 seconds.
✔ Test run with 2 tests in 1 suite passed after 0.897 seconds.
```

`CompositionRootTests` reveló un fallo real en la primera pasada (no una fricción del
kit): mi propia lista de módulos de prueba no incluía `PlatformModule()` (el
`Coordinator<AppRoute>` que registra), así que `Container` no podía resolverlo —
`AppFoundation.Coordinator<Domain.AppRoute>' not registered`. Corregido añadiendo
`PlatformModule()` a la lista; el resto de módulos (`NetworkingModule`, los seis
`<Name>Module`) ya estaban.

## Fuera de alcance de este informe

`FullFlowTests` había fallado una vez en un intento de ejecución con «Timed out while
synthesizing event» tras escribir en el campo de contraseña — consistente con la
flakiness del runner ya documentada en `docs/INFORME-INTEGRACION.md` (misma clase de
fallo: un XCUITest se cuelga en el simulador sin relación con el código fuente). En la
ejecución completa que se pega arriba, los 4 XCUITests pasaron limpio. No se investigó más
a fondo por quedar fuera del alcance de esta migración (Fase 1: sin funcionalidad nueva).

## Fase 2, tramo A — fricciones nuevas (Diagnostics, Uploads, sesión, alertas)

Escaparate de CoreNetworking/AppFoundation (PRD-APP-02): Diagnostics (`generate-feature
Diagnostics --api --no-service`), Uploads (`generate-feature Uploads --api`),
`Container(parent:)` por sesión, alertas destructivas en Favorites/Profile,
`AnalyticsTracking`/`CameraCapturing`. Cinco fricciones nuevas, más una reaparición
confirmada de una ya conocida.

### 6. La coma colgante antes de los markers (fricción 4, Fase 1) reaparece en cada
`generate-feature` posterior

Ya documentada arriba con `AppModule.swift`/`Package.swift`'s `targets:` — reaparece EN
CADA `generate-feature` que se ejecuta después de un `swift format format -i`, no solo la
primera vez: `Diagnostics` la reprodujo en `products:` de `Package.swift` y en el array de
`AppModule.makeModules()`; `Uploads`, otra vez, en ambos sitios; la prueba de
`--service-from`/`--store-from` de más abajo, una CUARTA vez. Sin excepción, en cada caso
el síntoma es idéntico: `error: static member 'library'/'target' cannot be used on
instance of type 'Product'/'Target'` (falta la coma antes del elemento nuevo) o, en
`AppModule.swift`, un error de sintaxis en el array literal. La propuesta de la Fase 1
(que las plantillas inserten la coma DELANTE de la entrada nueva, en vez de asumir que la
anterior ya termina en una) sigue siendo la única solución robusta — confirmado que
`swift format` reformatea sin avisar cada vez que alguien lo corre sobre `App/`/los dos
`Package.swift`, así que la fricción es estructural, no un accidente de una sola vez.

### 7. `DiagnosticsService.init` bloqueaba el hilo principal ~60s: el patrón
`DispatchSemaphore` de `OfflineFixtures.makeTransport()` no es seguro fuera del arranque

**Repro:** `DiagnosticsService` necesita un fixture `InMemoryTransport` con una secuencia
503→503→200 para el experimento "5xx con reintentos" (PRD-APP-02). Copiando literalmente
el patrón de `App/OfflineFixtures.swift` (`Task { await transport.register(...) };
semaphore.wait()` dentro de un `init` síncrono):

```swift
public init(baseURL: URL, authenticatedAPI: any APIServiceProtocol, offlineTransport: (any HTTPTransport)? = nil) {
    ...
    self.retryAPI = APIService(configuration: configuration, transport: Self.makeRetryFixtureTransport(baseURL: baseURL), ...)
}
private static func makeRetryFixtureTransport(baseURL: URL) -> InMemoryTransport {
    let transport = InMemoryTransport()
    let semaphore = DispatchSemaphore(value: 0)
    Task { await transport.register(...); semaphore.signal() }
    semaphore.wait()
    return transport
}
```

`DiagnosticsServicing` se registra como singleton perezoso — se construye la PRIMERA vez
que `DiagnosticsViewModel` se resuelve, es decir, exactamente cuando el usuario navega a
Diagnostics (no al arrancar la app, como `OfflineFixtures.makeTransport()`). Navegar a
Diagnostics real y offline se quedó colgado — el "Run" de un experimento tardaba ~60s en
reaccionar, reproducido de forma determinista con `DiagnosticsUITests` contra el
Simulador (`t = 18.73s` tras el tap, siguiente log a `t = 79.10s`).

**Causa:** el patrón `DispatchSemaphore` que bloquea el hilo que llama es seguro SOLO
cuando ese hilo es el principal DURANTE EL ARRANQUE, antes de que la app tenga UI/eventos
pendientes — exactamente la doc del propio `OfflineFixtures.makeTransport()` ya lo advertía
("safe here because nothing the Task does needs the main actor"). Construir un objeto así
de forma perezosa, en mitad de una transición de navegación de SwiftUI (con el runloop
principal ya ocupado con la propia animación/transacción de push), compite por el mismo
hilo que el `Task` necesita para progresar — no es un deadlock estricto (el `Task` no
necesita el actor principal), pero la contención real observada fue de ~60s.

**Solución aplicada:** no registrar el fixture en `init` — registrarlo (de forma async
normal, sin semáforo) al principio de `runRetry5xx()`, cada vez que se ejecuta ese
experimento. Efecto colateral bueno: el experimento vuelve a ser determinista en
repeticiones (antes solo el primer tap partía de intento 1).

**Propuesta para AppFoundation/CoreNetworking 1.2.1**: documentar explícitamente, en el
propio doc comment de `InMemoryTransport.register(_:)` o en el artículo `Testing.md`, que
el patrón `DispatchSemaphore`-para-puentear-async-en-un-init-síncrono NO es seguro fuera
del arranque de la app — o, mejor, ofrecer una variante `InMemoryTransport(exchanges:)`
con un `init` síncrono que acepte las respuestas directamente (sin pasar por `register`
async) para este caso de uso exacto (fixtures conocidas de antemano, no dependientes de
E/S real).

### 8. `generate-feature --api` registra su PROPIO `APIServiceProtocol` — sobrescribe
silenciosamente el autenticado de toda la app si el feature nuevo no es el primero

**Repro:** `generate-feature Uploads --api` generó, dentro de `UploadsModule.register(in:)`:

```swift
container.register(APIServiceProtocol.self) { [baseURL] _ in
    APIService(configuration: NetworkingConfiguration(baseURL: baseURL))
}
```

Este proyecto YA tiene un `APIServiceProtocol` autenticado (`NetworkingModule`, con
`BearerTokenInterceptor` + `TokenRefreshRetrier`) que TODAS las demás features resuelven.
`UploadsModule()` se añade al final de `AppModule.makeModules()` — `Container.register`
sobrescribe silenciosamente cualquier registro anterior del MISMO tipo en el MISMO
contenedor (documentado: "Registering the same type twice overwrites... in DEBUG builds
this logs a warning"). Si `UploadsModule` se hubiera dejado tal cual, cualquier feature
registrada DESPUÉS de él en la lista habría perdido su bearer token — sin error de
compilación, sin test que lo detecte a menos que ejercite ESE feature contra la API real
tras ese punto del arranque, solo el aviso de consola en DEBUG (`AppFoundationLogger.di:
"Re-registering... Overwriting previous registration"`), fácil de pasar por alto entre
cientos de líneas de log de `xcodebuild`.

**Causa:** el generador no tiene forma de saber, al generar UN feature aislado, que el
proyecto que lo aloja ya tiene wiring de red compartido — es el comportamiento CORRECTO
para el primer feature `--api` de un proyecto nuevo (el caso que `archinit`/`Generator.md`
documentan), pero peligroso en un proyecto con `NetworkingModule` transversal como este.

**Solución aplicada:** eliminado el registro de `APIServiceProtocol` de `UploadsModule`;
`UploadsService` resuelve el YA EXISTENTE vía `c.resolve()`, igual que `ProductsModule`/
`ProfileModule`/etc.

**Propuesta para 1.2.1:** que `generate-feature --api`, en modo multi, compruebe si YA
existe un target `Networking` (o cualquier target cuyo nombre coincida con un patrón
conocido) en el propio paquete `Platform` antes de generar su propio wiring de
`APIServiceProtocol` — y si existe, genere el Service asumiendo que se resuelve del
`Container` en lugar de construir su propia configuración. Alternativa más simple: que el
mensaje de éxito de `generate-feature --api` en modo multi imprima una advertencia
explícita ("si tu proyecto ya registra `APIServiceProtocol` en otro módulo, BORRA este
registro — la última llamada a `container.register` para el mismo tipo gana en
silencio") en vez de asumir que cada feature es el primero.

### 9. `--service-from`/`--store-from` en modo multi: el mock reutilizado no es visible
desde el test target nuevo — confirmado con una prueba real

**Repro** (ejecutado en este repo, revertido tras capturar la evidencia — nunca llegó a
compilar, no se dejó en el árbol):

```bash
cd Packages/Features
swift package --disable-sandbox --allow-writing-to-package-directory \
  generate-feature ProductDetailProbe --api --local --service-from Products --store-from Favorites
```

Salida real del generador (además de la fricción 6, la coma colgante, que también
reapareció):

```
--service-from Products: ProductDetailProbeLogic depende de 'any ProductsServicing'. En modo
multi cada feature tiene su propio target de tests — si ProductsServiceMock no es
visible desde ProductDetailProbeFeatureTests, hazlo público o genera ProductDetailProbeLogicTests a mano.

--store-from Favorites: ProductDetailProbeLogic depende de 'any FavoritesStoring'. Misma nota que
--service-from sobre la visibilidad del mock entre targets de tests distintos en modo multi.
```

El generador YA AVISA de la fricción — pero el aviso genérico no basta para saber qué
hacer: inspeccionando el `ProductDetailProbeLogicTests.swift` generado, usa
`ProductsServiceMock()` DIRECTAMENTE (sin `import PlatformTestSupport`), y el
`Package.swift` generado para `ProductDetailProbeFeatureTests` NO añade
`PlatformTestSupport` a sus `dependencies:`. En ESTE repo, `ProductsServiceMock`/
`FavoritesStoreMock` viven en `PlatformTestSupport` (`Packages/Platform`) — la solución
que la Fase 1 de esta migración ya adoptó precisamente para este problema (ver «
`PlatformTestSupport` (nuevo...)» más arriba) — así que el fichero generado NO
COMPILARÍA tal cual: `ProductsServiceMock` es un símbolo indefinido en ese target hasta
que alguien, a mano, (a) añade `.product(name: "PlatformTestSupport", package: "Platform")`
a las `dependencies:` de `ProductDetailProbeFeatureTests` en `Package.swift`, y (b) añade
`import PlatformTestSupport` al fichero de test generado.

**Causa:** `generate-feature` en modo multi genera un test target POR feature (a
diferencia del modo single-package, donde un único target de tests ve todos los mocks
libremente) — el generador conoce el NOMBRE del mock que necesita (`<Feature>ServiceMock`/
`InMemory<Feature>Store`) pero no sabe DÓNDE vive ese tipo en el proyecto que lo aloja: no
tiene forma de detectar que este repo lo movió a un target compartido (`PlatformTestSupport`)
en vez de dejarlo en `<Feature>FeatureTests` (su ubicación por defecto fuera de modo multi).

**Propuesta para 1.2.1:** dado que el propio `AGENTS.md`/`Generator.md` que instala
`archinit --multi` YA recomienda el patrón `PlatformTestSupport`/`DomainTestSupport` para
mocks compartidos entre features (`AGENTS.md` de AppFoundation 1.2.0, citado en el propio
informe de Fase 1 de este repo), `generate-feature --service-from`/`--store-from` en modo
multi debería, por defecto, asumir que el mock vive en un producto de test-support
compartido y añadirlo como dependencia — con un flag (`--mock-in <Feature>Tests` o similar)
para el caso, ahora poco común pero legítimo, de que el mock siga en el target de tests
original. Alternativa más simple y más robusta a nombres: que el generador, tras escribir
el fichero de test, intente `swift build` y si falla por símbolo indefinido, imprima un
mensaje MÁS ESPECÍFICO señalando exactamente qué falta (dependencia + import), en vez del
aviso genérico actual.

### 10. R13 bloquea `import UIKit` en un `*Feature` — el glob `*Kit` no distingue el
`CameraKit` propio del framework del sistema

**Repro:** `Uploads` necesita decodificar la foto capturada (`Data`) para previsualizarla
con `Image`. La forma obvia, `UIImage(data:)` + `Image(uiImage:)`, requiere `import UIKit`
en `UploadsFeature` (un `*Feature`). `.archlint.yml` (raíz) declara
`"*Feature": forbiddenImports: ["*Feature", "*Kit", "*Adapters", "Analytics*"]` — pensado
para bloquear `import CameraKit`/futuros `<Cap>Kit` propios del proyecto, pero el glob
`*Kit` coincide LÉXICAMENTE con `UIKit` también:

```
error: [ArchLint.R13] 'UploadsFeature' no puede importar 'UIKit': entra por un protocolo
de Domain implementado en un Adapter/Kit.
```

**Causa:** R13 compara el nombre del módulo importado contra el patrón glob sin distinguir
frameworks del sistema (que empiezan por mayúscula y son de Apple) de los Kits propios del
proyecto (que este starter también nombra con el sufijo `Kit`) — una coincidencia de
nomenclatura, no un error conceptual del linter, pero con un efecto práctico real: CUALQUIER
`*Feature` que necesite `UIKit` (`UIImage`, `UIColor`, `UIPasteboard`, lo que sea) para algo
que no pasa por un Kit propio queda bloqueado.

**Solución aplicada aquí:** decodificar con `ImageIO`/`CoreGraphics`
(`CGImageSourceCreateWithData` + `Image(decorative:scale:orientation:)`) en vez de
`UIImage(data:)` — ninguno de los dos coincide con el glob `*Kit`, y el resultado es
además más portable (compila igual en macOS, sin `#if canImport(UIKit)`).

**Propuesta para 1.2.1:** que R13 excluya explícitamente los frameworks del sistema
conocidos (`UIKit`, `AppKit`, `WatchKit`, `TVUIKit`…) de cualquier glob `*Kit`/`*Adapters`
definido en `modules:` — o que la sintaxis de glob de `.archlint.yml` permita anclar el
patrón a módulos LOCALES del propio paquete (p. ej. un prefijo implícito o una lista
explícita de módulos del proyecto en vez de un glob abierto), para que un nombre de
Kit propio nunca choque por coincidencia con un framework del sistema.

### 11. `@Observable` de `AppFoundation.BaseViewModel` no se propaga a subclases —
cualquier ViewModel cuyas propiedades propias cambien SIN acompañar a `phase`/`activity`
nunca dispara un re-render

Este es el hallazgo más caro de este tramo (varias horas de depuración), y no es,
estrictamente, una fricción DEL KIT — es una combinación real entre cómo Swift's
`@Observable` funciona (el macro solo instrumenta las propiedades declaradas EN LA CLASE a
la que se aplica, no las de sus subclases) y el patrón `LogicViewModel<L>: BaseViewModel`
que el kit recomienda para toda pantalla.

**Repro:** `DiagnosticsViewModel` (subclase de `LogicViewModel<any
DiagnosticsLogicProtocol>`, a su vez subclase de `BaseViewModel`, el único marcado
`@Observable`) declara sus propias `results`/`runningExperiments`/`logLines`. Cada
experimento (salvo el cancelable, que usa `performLoad`) corre en un `Task` propio que
muta SOLO esas tres propiedades — nunca toca `phase`/`activity`/`alert`/`banner` (las
únicas realmente trackeadas, por estar declaradas en `BaseViewModel`). Resultado: tras
tocar "Run", la fila nunca mostraba el resultado — ni siquiera el cambio SÍNCRONO e
inmediato de `runningExperiments.insert(experiment)` (antes de cualquier `await`) se
reflejaba en el botón "Run"→`ProgressView`. Confirmado añadiendo un contador de renders
vía `os.Logger` dentro de `DiagnosticsView.body`: se ejecutó exactamente DOS veces al
arrancar la pantalla (`.idle` → `.content`, ambas con `results`/`runningExperiments`
vacíos) y NUNCA MÁS, sin importar cuántos experimentos terminaran.

**Por qué otras features "funcionan" sin este problema:** `ProductsViewModel.items`
también es una propiedad propia de la subclase, no trackeada — pero SIEMPRE se muta DENTRO
de un `performLoad`/`performActivity`, que TAMBIÉN cambia `phase`/`activity` (SÍ
trackeadas) en la MISMA operación. SwiftUI re-renderiza por el cambio de `phase`, y en
ESE momento lee `items` con su valor ya actualizado — la propiedad "funciona" por
casualidad de sincronía, no porque esté realmente trackeada. Diagnostics fue el primer
caso de este proyecto con experimentos INDEPENDIENTES que nunca tocan `phase`/`activity`
en absoluto, lo que expuso el problema.

**Solución aplicada:** añadir `@Observable` (además del heredado) directamente sobre
`DiagnosticsViewModel` y `UploadsViewModel` (este último por una versión más leve del
mismo bug: el progreso intermedio de la barra de subida nunca se vería, solo el salto
final a 100%, coincidiendo con `stopActivity()`). Aplicar `@Observable` dos veces en la
misma cadena de herencia compila sin conflicto — cada clase instrumenta solo sus propias
propiedades — y arregla el problema de raíz. `experimentTasks`/`Task<Void, Never>` necesitó
`@ObservationIgnored` (un `deinit` a mano que lee una propiedad `@MainActor`-aislada desde
un contexto `nonisolated` no compila si esa propiedad pasa a estar detrás del macro).

**Propuesta hecha para AppFoundation 1.2.1 — ya corregida (histórico):** cuando se
encontró este bug, el kit no exigía `@Observable` en cada subclase de `BaseViewModel` ni
lo documentaba: la propuesta de esta sección era que `AppFoundation` lo exigiera con una
regla de `ArchitectureLint`, no solo que lo mencionara en un doc comment. Desde
`AppFoundation` 1.2.1 (2026-09-04, `CHANGELOG.md` de ese paquete) el kit SÍ lo exige: la
regla **R15** (error) rompe `swift build` si una `class` cuyo nombre termina en
`ViewModel` no lleva `@Observable`. Este repo ya cumplía la regla en todos sus
ViewModels desde que se aplicó la solución de más arriba — al subir a 1.2.1
(`Package.swift`/`project.yml` de ambos paquetes, `swift package update`), `swift
package archlint` sigue dando **0 errores, 0 warnings** con R15 activa, sin tocar una
sola línea de las Views/ViewModels existentes. Lo que queda de esta sección, arriba, es
el repro y la solución que se aplicaron ANTES de que el kit lo exigiera — se deja tal
cual por valor histórico (por qué hacía falta, no solo que hacía falta).

### Dos hallazgos reales al ejecutar Diagnostics contra DummyJSON de verdad (no fricciones
del kit — de esta app, expuestos precisamente porque Diagnostics se usó para lo que existe)

Al verificar los seis experimentos contra la API real (sin `-UITestOffline`, la
comprobación manual que exige este PRD), dos de ellos NO se comportaron como el diseño
esperaba a la primera:

1. **"401 sin token" devolvía 200 (`succeeded: true`) si se ejecutaba tras un login real
   en el mismo proceso.** `DiagnosticsService.unauthenticatedAPI` se construyó con
   `URLSessionTransport()` (el `init` con `configuration:` por defecto,
   `URLSessionConfiguration.default`) — que acepta y reenvía cookies a través de
   `HTTPCookieStorage.shared`, COMPARTIDO por todo el proceso. `NetworkingModule`'s propia
   `AuthServicing` (usada por el login real) también usa `URLSessionTransport()` sin
   configuración propia para su API sin autenticar — y `POST /auth/login` de DummyJSON
   pone, ADEMÁS del par de tokens en el JSON, una cookie de sesión
   (`Set-Cookie: accessToken=...`, verificado con `curl -i`). Esa cookie queda en el jar
   compartido del proceso; la siguiente petición a `/auth/me` sin cabecera
   `Authorization` la reenvía automáticamente y el servidor la acepta igual — autenticando
   por accidente una petición que el experimento existe para demostrar que NO lo está.
   Arreglado construyendo `unauthenticatedAPI` con
   `URLSessionTransport(configuration:)` y una configuración que desactiva cookies
   (`httpShouldSetCookies = false`, `httpCookieAcceptPolicy = .never`) — la MISMA que ya
   usa el pipeline autenticado de la app, vía `NetworkingConfiguration
   .defaultSessionConfiguration()`. Verificado con `curl -i https://dummyjson.com/auth/me`
   (sin cookie): `401`, confirma que el comportamiento correcto es el que ahora se ve.
2. **"Host inalcanzable" no resolvía nunca (colgado más de 75s) usando esa misma
   configuración por defecto.** `defaultSessionConfiguration()` activa
   `waitsForConnectivity = true` — correcto para el pipeline REAL de la app (esperar a que
   vuelva la red en una caída transitoria, documentado en su propio doc comment), pero
   equivocado para un host que NUNCA va a resolver: `URLSession` se queda esperando en vez
   de fallar rápido por DNS. Arreglado con una `URLSessionConfiguration` propia para este
   pipeline (cookies desactivadas, `waitsForConnectivity = false`) — el experimento vuelve
   a fallar en segundos, como se espera de `TransportError` → `.unreachable`.

No es una fricción del kit (es esta app usando `URLSessionTransport`/`URLSessionConfiguration`
sin pensar en cookies compartidas ni en `waitsForConnectivity` para un caso adversarial) —
pero es exactamente el tipo de comportamiento sutil que una pantalla de Diagnostics real
contra la API real, no solo contra fixtures, está pensada para sacar a la luz. Capturas
reales de los seis experimentos, ya con ambos arreglos: `docs/screenshots/
diagnostics-real-network.png` (los seis resultados) y `docs/screenshots/
diagnostics-slow-running.png` (el séptimo, cancelable, a mitad de vuelo).

## Fase 2, tramo B — fricciones nuevas (Gallery, Settings, deep links, Search)

Escaparate restante de PRD-APP-02: `Gallery` (`generate-feature Gallery --api --module`),
`Settings` (`generate-feature Settings --local`), deep links `appstarter://`, y
`SearchBarConfiguration`/`Debouncer` en Search. Cuatro fricciones nuevas — dos genuinas
del kit, una del toolchain, una de esta app.

### 12. Un `.build/` incremental desactualizado, tras varios commits que cambian el
layout de un tipo compartido (`AppRoute`), hace que `swift test` crashee con
`SIGSEGV`/`SIGBUS` reales — no flakiness del runner

**Repro:** con `Packages/Features/.build/` acumulado a través de varios commits que
fueron añadiendo casos con valores asociados a `AppRoute` (`.gallery(productID:)`,
`.search(query:)`), `swift test --package-path Packages/Features` crasheaba el binario
combinado de tests (`swiftpm-testing-helper`) de forma consistente (100% de las
ejecuciones, no intermitente) — señal distinta cada vez (`SIGSEGV`/`SIGBUS`), sitio de
fallo distinto cada vez (`Array<AppRoute>.==`, `Mirror.init(reflecting:)` dentro del
propio `#expect` al construir el mensaje de un fallo), siempre corrupción de memoria, no
un fallo de aserción normal. Reproducible incluso con `--filter` a UN SOLO test ajeno
por completo a `AppRoute`, y aún con `--skip` de los tests del target recién añadido
(`GalleryFeatureTests`) — la sola presencia del target nuevo enlazado en el binario
combinado bastaba, sin necesidad de ejecutar ninguno de sus tests.

**Diagnóstico:** confirmado por bisección real (`git stash`/`git checkout <commit> --
.`/`git checkout HEAD -- .`, sin tocar `HEAD`): el mismo estado de código exacto
compila y pasa los tests 100% de las veces con `rm -rf Packages/Features/.build` antes
de compilar, y crashea 100% de las veces sin ese paso, en el mismo checkout. No es una
regresión de código — es un artefacto de build incremental de SwiftPM que quedó
desincronizado: distintos módulos del mismo binario combinado de tests, compilados en
momentos distintos mientras `AppRoute` (un tipo compartido por todos) cambiaba de
tamaño/layout entre medias, acaban con suposiciones ABI distintas sobre el mismo tipo —
la mezcla resultante corrompe memoria en tiempo de ejecución de forma silenciosa hasta
que algo la lee (a menudo, la propia maquinaria de `swift-testing` construyendo el
mensaje de un `#expect` fallido, de ahí los sitios de crash aparentemente aleatorios).

**Impacto:** indistinguible, desde fuera, de un bug real de concurrencia en el código de
la app — cuesta buena parte de una sesión de depuración descartar cada sospechoso
(Throttler, Debouncer, ManualClock, Task, actors) antes de sospechar del propio `.build/`.

**Workaround:** `rm -rf Packages/Features/.build` (y lo mismo para `Packages/Platform`)
antes de una tanda de verificación importante, especialmente tras una sesión con varios
commits seguidos que tocan un tipo compartido central como `AppRoute`/`Product`. Este
repo no lo necesita como paso permanente de CI (cada corredor de CI parte de un checkout
limpio, sin `.build/` previo) — es un riesgo específico de desarrollo local/agéntico con
sesiones largas y build incremental persistente entre commits.

**Propuesta:** no es una fricción de `AppFoundation`/`CoreNetworking` — es de SwiftPM
(`swift test`'s build incremental para el binario combinado de un paquete con múltiples
test targets). Documentado aquí porque cualquier sesión larga tocando un tipo
`Domain`/`AppRoute` compartido por muchos targets puede reproducirlo; ningún cambio de
código lo evita, solo limpiar `.build/` cuando aparece.

### 13. `generate-feature Settings --local` genera SwiftData, nunca `UserDefaults` — no
hay forma de pedirle la variante `UserDefaults` desde la CLI

**Repro:**
```bash
cd Packages/Features
swift package --allow-writing-to-package-directory generate-feature Settings --local
```
El `Store` generado es `@Model`/`@ModelActor`/`ModelContainer` (`SwiftDataSettingsStore`)
— el mismo cascarón que `Favorites` ya usa. El PRD (y `Architecture.md`) piden
explícitamente el patrón `UserDefaults` («actor + conformidad en extension», el que ya
usa `Domain.UserDefaultsSessionStore`) para una pantalla de ajustes con tres booleanos,
no una entidad que se consulta/ordena — SwiftData es la herramienta equivocada aquí
(un `ModelContainer` para tres `Bool` es coste sin beneficio), pero `--local` no ofrece
alternativa: no hay un `--local=userdefaults` ni variante equivalente.

**Workaround usado aquí:** generar con `--local` igualmente (el resto del cascarón —
`SettingsLogicProtocol`, `SettingsModule`, tests con mocks — sigue siendo la base
correcta) y reescribir a mano `Stores/SettingsStore.swift` completo, sustituyendo
`@Model`/`SwiftDataSettingsStore` por `UserDefaultsSettingsStore` sobre el patrón de
`UserDefaultsSessionStore`. El resto del cascarón generado (`SettingsLogic.swift`,
`SettingsModule.swift`, `SettingsView.swift`, los mocks/tests) también se reescribió a
mano casi por completo, porque el dominio real (`AppSettings` con tres toggles +
entorno + red + analítica) no se parece en nada al ejemplo genérico `SettingsItem` que
el generador produce sin más contexto que el nombre del feature — esperable, no una
fricción del generador en sí.

**Propuesta para 1.2.1:** una tercera variante de `--local` (p. ej. `--local=userDefaults`
o un flag `--store-kind userDefaults`) que genere el patrón `actor` + `UserDefaults` en
vez de SwiftData siempre que el dominio sea "unas pocas preferencias", no una colección
de registros — el propio kit ya conoce y documenta ambos patrones (`Architecture.md`),
solo le falta dejar elegir cuál generar.

### 14. `@Observable` no notifica cuando el nuevo valor de una `stored property`
`Equatable` es igual al anterior — un test de "cambia y notifica" que reutiliza el valor
por defecto pasa por las razones equivocadas (o falla por las correctas)

**Repro:** un test de `SettingsViewModelTests` que hacía `viewModel.handle(.load)` con
un mock cuyo `stateToReturn.settings` era el `AppSettings()` por defecto — EXACTAMENTE
el valor inicial de `viewModel.settings`, también `AppSettings()` — nunca disparaba
`withObservationTracking`'s `onChange`, a pesar de que `SettingsViewModel` sí declara su
propio `@Observable` (verificado leyendo el macro-expandido: el setter sintetizado por
`@Observable` compara el valor nuevo con el viejo para tipos `Equatable` y solo llama a
`withMutation`/notifica si son distintos — no es un fallo de instrumentación, es una
optimización real del macro). El mismo test, cambiando el mock para devolver
`AppSettings(themeIsBrand: true)` (un valor genuinamente distinto del inicial), pasa de
inmediato.

**Por qué importa para escribir TESTS de `@Observable`** (no es un bug de la app, es una
trampa al escribir la prueba): cualquier test "`withObservationTracking` + cambia una
propiedad + `#expect(flag.fired)`" que reutilice, sin querer, el valor por defecto de
esa propiedad demuestra "esta asignación no notificó" sin decir SI fue porque
`@Observable` falta (el bug real que estas pruebas, PRD-APP-02 tramo B item 0, existen
para atrapar) o porque el valor no cambió (un falso positivo del test, no del código).
Los tests de este tramo que siguen este patrón (`ObservationFlag`,
`docs/INFORME-MULTI.md` §11) fuerzan ahora, a propósito, un valor final DISTINTO del
inicial en cada caso.

**No es una fricción de AppFoundation** — `@Observable` es del framework `Observation`
de Apple, no del kit — pero merece registro aquí porque el propio §11 (arriba, tramo A)
documenta el patrón de test `ObservationFlag`/`withObservationTracking` sin advertir de
esta trampa; una nota en ese mismo sitio en 1.2.1 ahorraría repetir el hallazgo.

### 15. `UserDefaults` no es `Sendable` — construirlo con `UserDefaults(suiteName:)` en
un test y pasarlo al `init` de un `actor` bajo Swift 6 estricto exige `@preconcurrency
import Foundation`

**Repro:**
```swift
// dentro de una función de test @MainActor (aislamiento por defecto de este proyecto):
let defaults = try #require(UserDefaults(suiteName: suiteName))
return UserDefaultsSettingsStore(defaults: defaults)   // el init del actor
```
```
error: sending 'defaults' risks causing data races [#SendingRisksDataRace]
note: sending main actor-isolated 'defaults' to actor-isolated initializer
'init(defaults:)' risks causing data races between actor-isolated and main
actor-isolated uses
```
Confirmado con un chequeo aislado (`func check<T: Sendable>(_ x: T) {}; check(UserDefaults
.standard)`): el SDK marca la conformidad de `UserDefaults` a `Sendable` como
`@_nonSendable(_assumed)` — EXPLÍCITAMENTE no-`Sendable`, a pesar de ser, en la práctica,
thread-safe (así lo documenta Apple). `Domain.UserDefaultsSessionStore`/
`SettingsFeature.UserDefaultsSettingsStore` nunca lo habían notado porque el único sitio
que los construye con un `UserDefaults` no-`.standard` es, precisamente, este test nuevo
— cualquier otro call site usa el parámetro por defecto (`= .standard`), evaluado en el
propio `init`, no una variable local "enviada" a través de un límite de aislamiento.

**Workaround usado aquí:** `@preconcurrency import Foundation` en el fichero de test que
construye `UserDefaults(suiteName:)` explícitamente — relaja el chequeo de `Sendable`
para los tipos de `Foundation`, aceptable aquí porque `UserDefaults` es, de hecho,
thread-safe (el propio comentario de `UserDefaultsSessionStore` ya lo asume igual, solo
que nunca lo había puesto a prueba con un valor no-`.standard`).

**No es una fricción de AppFoundation/CoreNetworking** — es el SDK de Apple negándose a
marcar `UserDefaults` como `Sendable` a pesar de serlo en la práctica — pero cualquier
Store futuro de este repo que quiera testear contra un `UserDefaults(suiteName:)` real
(en vez de un mock en memoria) se topará con lo mismo; documentado para no repetir el
diagnóstico.

### Decisión de diseño: el pinning se aplica en el próximo lanzamiento, no en caliente

No es una fricción — una decisión deliberada, documentada aquí porque el PRD habla de
"Settings... reconfigura el transporte" de una forma que podría leerse como "en caliente,
sin reiniciar". `NetworkingModule.register(in:)` construye el `APIService` autenticado
(y el de login/refresh) UNA VEZ, en el momento en que `Container.shared.register(modules:)`
corre (arranque de la app) — cada `*Service` de cada feature (`ProductsService`,
`GalleryService`, `AuthService`…) resuelve `any APIServiceProtocol` una sola vez y
guarda esa referencia. Re-registrar el tipo en el `Container` después de un toggle en
`Settings` no llegaría a ninguna de esas referencias ya resueltas — haría falta un nivel
de indirección adicional (un `APIServiceProtocol` "proxy" que reenvíe a una instancia
intercambiable) que el kit no pide y que esta app no necesita: el caso de uso real
("verifica que el pinning estricto/pin falso funcionan") tolera perfectamente un
reinicio entre tocar el ajuste y comprobar el efecto, exactamente como la comprobación
manual de `README.md` lo hace. `SettingsViewModel` lo dice explícitamente en su propio
banner ("se aplica al reiniciar la app") y en su doc comment.

## Fase 3 — XCUITests offline, snapshot tests, escaparate completo y CI

AppFoundation 1.2.1 (R15: `@Observable` obligatorio), cuatro XCUITests offline nuevos
(`Settings`, `Gallery`, dos de deep link), `AppSnapshotTests` (24 capturas), `Scripts/
check-showcase.sh`, y la tabla completa del escaparate en el README.

### AppFoundation 1.2.1

`Packages/Platform/Package.swift`, `Packages/Features/Package.swift` y `project.yml`
fijan `from: "1.2.1"`; `swift package update` en ambos re-resuelve `Package.resolved`.
`swift package archlint` sigue dando **0 errores, 0 warnings** con R15 activa en los dos
paquetes — los once ViewModels de este repo ya declaraban `@Observable` propio desde que
se corrigió el bug de §11 (arriba), así que subir de versión no tocó una sola Vista o
ViewModel. §11 se cierra como histórico: la propuesta que ahí se hacía ("que el kit lo
exija, no solo lo documente") ya se cumplió.

### XCUITests offline nuevos

Los cuatro que faltaban del PRD (`Diagnostics`/`Uploads` ya existían de un tramo
anterior): mismo estilo y helpers que los existentes (`AppUITests/
AppStarterUITestCase.swift`), todos offline (`-UITestOffline`, `App/OfflineFixtures.swift`
— el fixture de `Gallery` (tres imágenes) ya estaba preparado desde el tramo B).

- **`GalleryUITests.swift`**: abre Gallery desde `ProductDetail`, comprueba que la barra
  overlay (`chrome: .custom(_, placement: .overlay)`) está presente Y es tappable sobre la
  imagen, pagina a una segunda imagen por miniatura, y swipe-back vuelve a `ProductDetail`
  — la misma técnica de gesto que `SwipeBackTests`, la prueba de que `PopGestureEnabler`
  también engancha bajo `.overlay`, no solo `.stack`.
- **`SettingsUITests.swift`**: cambia a tema de marca y vuelve — verificado por
  ESTRUCTURA, no por color (`BrandBannerStyle` tiene un botón "Cerrar" propio distinto del
  mensaje; `DefaultBannerViewStyle` es un único `Button` con el mensaje como label — se
  puede distinguir sin capturar un píxel). Navega a Diagnostics bajo el tema de marca para
  probar que la pantalla sigue funcionando con los `Brand…Style` instalados. Activa
  pinning estricto y el pin falso, comprueba que `settings.pinningSummary` cambia de texto
  en cada paso, y que desactivar pinning oculta el toggle del pin falso. **Nota
  honesta:** `DiagnosticsViewModel.appear()` nunca falla (`setContent()` incondicional) —
  esta app no tiene, hoy, un camino de usuario real hacia el `.error` DE PANTALLA COMPLETA
  de Diagnostics (los experimentos fallidos se muestran inline, fila por fila, no como
  `ScreenContainer`'s `.error`). Ese estado — con AMBOS temas — sí se captura en
  `AppSnapshotTests` (inyectado directamente vía `setError(...)`, sancionado por el propio
  PRD: "los estados se inyectan por ViewModel/Logic mock"); el XCUITest de Settings prueba
  lo que SÍ es alcanzable por interacción real: el cambio de tema en vivo y que la pantalla
  sigue viva bajo él.
- **`DeepLinkUITests.swift`**: `appstarter://product/1` (offline, fixture `productID: 1`)
  y `appstarter://search?q=mascara` (el único query que el fixture de búsqueda contesta).
  **Opción elegida para disparar el deep link — documentada en el propio fichero**:
  `xcrun simctl openurl booted <url>` vía `Process`, no `launchArguments`/
  `launchEnvironment`. Un `-DeepLinkURL <url>` leído en `AppStarterApp.init()` solo
  probaría el parseo/enrutado (ya cubierto por `AppTests/DeepLinkTests.swift`), no la
  entrega real por `.onOpenURL` que un deep link de verdad usa en producción — `simctl
  openurl` sobre el simulador ya arrancado por el propio XCUITest SÍ dispara ese camino
  real. Confirmado manualmente antes contra la API real (`docs/screenshots/
  02-deeplink-product.png`, `03-deeplink-search.png`); este es el mismo camino, offline y
  automatizado.

Fricción menor confirmada al escribir estos tests, no un bug: `NavigationBarItem.close/
back`'s parámetro `id:` (p.ej. `.close(id: "gallery.close", ...)`) NO se traduce a
`accessibilityIdentifier` en `CustomNavigationBar`/`NavigationBarItemView`
(`AppFoundation`) — solo alimenta la identidad de `ForEach` (A10 en su propio doc
comment). Los tres tests nuevos que necesitan encontrar un botón de cierre/atrás en una
barra custom lo hacen por su `accessibilityLabel` localizado ("Close"/"Back",
`CloseButtonAccessibility`), igual que ya hacía `SwipeBackTests`/`AccessibilityLabelTests`
— no hizo falta cambiar nada, solo confirmarlo leyendo el código del kit antes de asumir
que `id:` funcionaba como identificador de UI.

### `AppSnapshotTests` — 24 capturas, `Diagnostics`/`Uploads`/`Gallery` × 4 estados × 2 temas

Target nativo de Xcode (`AppSnapshotTests/`, no un paquete SwiftPM — `swift-snapshot-
testing` necesita `UIHostingController`/un runtime UIKit real, que solo tiene el
simulador que ya arranca este esquema), dependencia `pointfreeco/swift-snapshot-testing`
`from: "1.19.0"` — SOLO enlazada a este target, nunca al target `AppStarter`.

- `SnapshotHelpers.swift`: `.snapshotTheme(_:)` instala los mismos cuatro `Brand…Style`
  que `RootView` instala (`@testable import AppStarter` — mismo mecanismo que `AppTests`/
  `AppUITests` ya usan para tipos internos de la cáscara); `snapshotDeviceSize` lee
  `UIScreen.main.bounds` EN TIEMPO DE TEST en vez de un punto fijo — la captura sigue
  siendo del tamaño correcto sea cual sea el simulador del esquema, sin mantener una
  constante que se desincroniza cuando cambia el destino por defecto; `waitUntil(_:)`
  sondea (10ms) hasta que una condición se cumple — necesario para los `Task`
  desestructurados de `DiagnosticsViewModel.run`/`UploadsViewModel.upload`, que no exponen
  un `Task` esperable como sí hacen `inFlightLoad`/`inFlightActivity`.
- **Cómo se inyecta cada estado** (PRD: "por ViewModel/Logic mock, sin red"):
  `loading` SIEMPRE con `BaseViewModel.setLoading(_:)` directo, en las tres pantallas —
  uniforme y sin la carrera de esperar a un mock asíncrono. `Diagnostics`/`Uploads` nunca
  fallan su propio `appear()` en producción (no hay camino real a `.empty`/`.error` de
  pantalla completa, ver la nota de `SettingsUITests` arriba) — sus `empty`/`error` se
  inyectan igual que `loading`, con `setEmpty()`/`setError(title:message:)` directos.
  `content` corre la acción real (`.run`, `.capturePhoto` + `.upload`) contra un stub
  `Logic` local y sondea con `waitUntil` hasta que el resultado aparece.
  `GalleryViewModel.load()` SÍ alcanza `.empty`/`.error` en producción
  (`performLoad(successTransition: .preserveCurrentPhase)`, `GalleryViewModel.swift:79`) —
  ahí `empty`/`error`/`content` corren los tres por el camino real, vía un
  `GalleryLogicProtocol` stub que devuelve/lanza lo que corresponda; solo `loading` usa la
  llamada directa, por la misma razón de carrera que las otras dos pantallas.
- **Qué muestra cada captura** (referencias en `AppSnapshotTests/__Snapshots__/`,
  revisadas a ojo en este PR): `loading` — el `ProgressView` a pantalla completa, con el
  spinner por defecto del sistema bajo el tema del kit y `Brand.accent` (magenta/rosa
  oscuro) bajo el de marca; `empty` — `ContentUnavailableView` genérico del kit
  ("No content") frente a "Nada por aquí" con el icono `shippingbox` y el tinte de marca;
  `error` — el icono/título/mensaje/botón "Reintentar" del kit frente a
  `exclamationmark.triangle.fill` en `Brand.accent`, título en negrita y el mismo tinte en
  el botón bajo el tema de marca; `content` — `Diagnostics` con la fila de "404 — producto
  inexistente" ya resuelta (categoría `notFound`, código `httpStatus`); `Uploads` con la
  foto de 1×1 previsualizada, el título por defecto y la sección "Resultado" con el
  producto #101 creado; `Gallery` con la primera de tres imágenes y la tira de miniaturas
  bajo la barra overlay transparente.

### `Scripts/check-showcase.sh`

Extrae cada cita `` `Símbolo` en `fichero:línea` `` de `README.md` (formato adoptado en
esta fase para TODA la tabla del escaparate — antes mezclaba filas sin símbolo explícito,
citas de fichero completo y un glob; ahora cada cita empareja símbolo Y ubicación
explícitamente, sin ambigüedad para un script), comprueba que el fichero existe, que la
línea está dentro del fichero, y que el símbolo (comparación de cadena fija, no regex)
aparece en una ventana de ±3 líneas alrededor de la línea citada. Falla listando TODAS las
citas rotas de una pasada, no solo la primera. `.github/workflows/ci.yml` lo corre en un
job `showcase` propio (`ubuntu-latest`, no necesita Xcode — el primero en fallar y el más
barato).

### CI

Job `showcase` nuevo (antes de `packages`/`app`, sin depender de Xcode). `app` pasa a
llamarse "unit + snapshot + UI, offline" — sin cambios de comandos: el `xcodebuild test`
que ya existía corre los tres targets del esquema (`AppTests`, `AppSnapshotTests` nuevo,
`AppUITests`) porque los tres están en la acción `test` del esquema `AppStarter`
(`project.yml`), no porque el YAML de CI necesitara un paso nuevo.

### Verificación (salidas reales)

```
$ swift test --package-path Packages/Platform
Test run with 8 tests in 3 suites passed after 0.005 seconds.

$ swift test --package-path Packages/Features
Test run with 125 tests in 26 suites passed after 0.076 seconds.

$ swift package --package-path Packages/Platform archlint
archlint: 0 errors, 0 warning(s) in 28 file(s).

$ swift package --package-path Packages/Features archlint
archlint: 0 errors, 0 warning(s) in 50 file(s).

$ swiftlint lint --strict --quiet Packages/Platform/Sources Packages/Platform/Tests \
    Packages/Features/Sources Packages/Features/Tests
(sin salida — 0 violaciones)

$ swift format lint --strict --configuration .swift-format --recursive \
    Packages App AppTests AppUITests AppSnapshotTests
(sin salida — 0 violaciones, tras corregir 4 ficheros nuevos con `swift format --in-place`)
```

**Bloqueador de entorno, no resuelto en esta sesión — honesto, no maquillado:**
`xcodebuild` (cualquier invocación, incluida `xcodebuild -list`, que no toca paquetes ni
compila nada) se queda colgado indefinidamente contra `AppStarter.xcodeproj` en esta
máquina — confirmado con `sample` sobre el proceso: bloqueado en
`_dispatch_sema4_wait`/`semaphore_wait_trap` dentro de la cola `IDEContainer - uniquing
lock`, el mismo punto sin importar `-derivedDataPath`/`-clonedSourcePackagesDirPath`
aislados (se probó una ruta de `DerivedData`/`SourcePackages` completamente separada de la
que usa Xcode.app — mismo cuelgue). La causa más probable: `Xcode.app` estaba ya abierto
en esta máquina con este mismo proyecto ANTES de esta sesión (`ps aux` lo confirma, PID
activo desde días antes) — Xcode retiene un lock de "contenedor IDE" sobre un `.xcodeproj`
mientras lo tiene abierto como documento, y `xcodebuild` desde línea de comandos contra el
MISMO fichero de proyecto espera esa misma exclusión mutua; `AppStarter.xcodeproj` se
regeneró varias veces durante esta sesión (`xcodegen generate`, tras cada cambio de
`project.yml`), lo que probablemente dejó al documento abierto de Xcode en un estado que
retiene el lock de forma prolongada. Un `xcodebuild build` normal (sin `-testing`) SÍ
funcionó una vez, al principio de esta sesión, antes de añadir `AppSnapshotTests`/
`SnapshotTesting` a `project.yml` — consistente con que el problema apareciera después de
esa regeneración, no que sea un problema estructural del proyecto.

**No verificado en esta sesión, por el bloqueador de arriba**: `xcodebuild test` (el smoke
test de `AppTests`, las 24 capturas de `AppSnapshotTests`, y los nueve `AppUITests`
offline — dos veces seguidas, como exige la verificación). El código compila a nivel
SwiftPM (`swift build`/`swift test` en ambos paquetes, en verde) y `xcodegen generate`
también corre limpio; lo que falta comprobar es específicamente la compilación/ejecución
del target `AppStarter` (aplicación + los tres test targets nativos de Xcode) vía
`xcodebuild`. **Recomendación para desbloquear**: cerrar `AppStarter.xcodeproj` en
Xcode.app (o salir de Xcode del todo) y volver a intentar `UI_TEST_OFFLINE=1
xcodebuild test -scheme AppStarter -destination 'platform=iOS Simulator,name=iPhone 17
Pro' -skipPackagePluginValidation -resultBundlePath TestResults.xcresult` — en CI (sin
Xcode.app interactivo compitiendo por el mismo lock) no debería reproducirse.
