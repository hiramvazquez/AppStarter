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
