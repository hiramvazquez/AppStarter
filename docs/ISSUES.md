# Issues propuestas

Cada una de estas fricciones (detalladas con contexto completo en
`docs/INFORME-INTEGRACION.md`) requiere un cambio en el paquete correspondiente, no solo
en AppStarter. Formato: título + descripción, listas para abrir tal cual en
`hiramvazquez/AppFoundation` o `hiramvazquez/CoreNetworking`.

> **Estado (2026-09-03):** las issues 1, 3 y 4 están resueltas en AppFoundation **1.0.1**
> y la 2 documentada con repro (`docs/repros/actor-inline-conformance.md` del paquete).
> Se conservan aquí como registro; AppStarter ya consume 1.1.0 (calidad de código incluida).

---

## AppFoundation

### 1. `swift package archlint` (sin `--path`) analiza `.build/checkouts`, incluidos los fixtures "malos" del propio paquete

**Descripción.** Ejecutar `swift package archlint` desde la raíz de un consumidor, sin
`--path Sources`, recorre TODO el árbol del paquete — incluido `.build/checkouts`, donde
viven los checkouts resueltos de AppFoundation y CoreNetworking. Como el propio
`AppFoundation` incluye fixtures deliberadamente inválidos para probar el linter
(`Tests/ArchLintTests/Fixtures/Bad/*.swift`, con violaciones R1-R9 a propósito), el
comando reporta más de 15 "errores" que no tienen nada que ver con el código del
consumidor:

```
.build/checkouts/AppFoundation/Tests/ArchLintTests/Fixtures/Bad/R1_BadViewModel.swift:10:22: error: [ArchLint.R6] ...
.build/checkouts/CoreNetworking/Sources/CoreNetworking/APIService.swift:1:1: error: [ArchLint.R3] Falta 'protocol XxxServicing: Sendable' ...
```

Con `--path Sources` el resultado es correcto (0 errores). El README y el artículo `Lint`
de DocC documentan `--path`, pero el comando SIN argumentos — el que cualquiera prueba
primero — produce una salida engañosa y alarmante en cualquier proyecto con dependencias
resueltas en `.build/`.

**Propuesta para 1.0.1.** `archlint` (y `ArchitectureLint`, el build-tool plugin) deberían
excluir `.build/`, `.swiftpm/` y `DerivedData/` del recorrido por defecto — igual que ya
excluyen `Tests/**` y los dobles de test — en vez de requerir `--path` para obtener un
resultado utilizable. Alternativa más barata: que el mensaje de ayuda / el propio output
avise cuando detecta que está analizando ficheros dentro de `.build/checkouts`.

---

### 2. `defaultIsolation(MainActor)` + `InferIsolatedConformances` rompe el `init` síncrono de un `actor` que conforma un protocolo `Sendable` con requisitos `async`, declarado inline

**Descripción.** Con las `swiftSettings` que el propio `GettingStarted.md` de
AppFoundation recomienda copiar (`defaultIsolation(MainActor.self)` +
`enableUpcomingFeature("InferIsolatedConformances")` + `NonisolatedNonsendingByDefault`),
este código NO compila:

```swift
protocol SessionStoring: Sendable {
    func currentAccessToken() async -> String?
}

actor UserDefaultsSessionStore: SessionStoring {   // ← conformidad INLINE
    private let defaults: UserDefaults
    private let key = "com.appstarter.session"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults   // error: actor-isolated property 'defaults' can not
    }                              // be mutated from the main actor
    ...
}
```

El error ("actor-isolated property can not be mutated from the main actor") aparece
incluso sin ningún `nonisolated` explícito — el `init` síncrono de un `actor`, que por
semántica normal de Swift está aislado a `self` (la nueva instancia), se infiere aislado
al actor GLOBAL por defecto (`MainActor`) en cuanto la conformidad a un protocolo
`Sendable` con requisitos `async` se declara EN LA MISMA declaración del tipo. Reproducido
en aislado (repro mínimo de 15 líneas, sin UserDefaults ni nada específico de AppStarter)
contra `swift-tools-version 6.2` / Xcode 26.6.

**El workaround que funciona**: declarar la conformidad en una `extension` SEPARADA:

```swift
actor UserDefaultsSessionStore {
    private let defaults: UserDefaults
    init(defaults: UserDefaults = .standard) { self.defaults = defaults }   // compila
    ...
}
extension UserDefaultsSessionStore: SessionStoring { ... }
```

**Propuesta para 1.0.1.** Esto es probablemente un bug de infra de aislamiento del
compilador más que de AppFoundation en sí, pero como AppFoundation es quien recomienda
esta combinación exacta de `swiftSettings` a cada consumidor (y el patrón "un `actor` que
implementa un `*Storing`/`*Servicing` propio" es EXACTAMENTE lo que `generate-feature
--local` genera), documentarlo explícitamente en `GettingStarted.md`/`Architecture.md` —
"declara la conformidad de tu Store/Service en una `extension` separada, no inline" —
ahorraría horas de depuración a cualquiera que siga el patrón `--local` al pie de la
letra. Vale la pena reportarlo también aguas arriba (swift-lang/swift), pero el fix de
documentación es inmediato y depende solo de AppFoundation.

---

### 3. `generate-feature` no tiene forma de decir "reutiliza el Service/Store de otra feature ya generada"

**Descripción.** El PRD de AppStarter comparte `ProductsServicing` entre tres features
(`Products`, `ProductDetail`, `Search`) y `FavoritesStoring` entre dos (`ProductDetail`,
`Favorites`) — exactamente el patrón que `AGENTS.md` describe como correcto ("un Service,
varios Logics que lo consumen por protocolo"). Pero `generate-feature ProductDetail --api
--local` genera SIEMPRE un `ProductDetailService.swift`/`ProductDetailStore.swift`
propios y nuevos — no hay forma de decirle "la mitad `--api` de esta feature en realidad
depende de `ProductsServicing`, no generes un Service nuevo". El resultado real: generar,
borrar los dos ficheros que sobran (`Services/ProductDetailService.swift`,
`Stores/ProductDetailStore.swift` en el caso `--local`), y editar a mano el `Logic`/
`Module` generados para inyectar el protocolo compartido en vez del que el generador
inyectó.

No es un bug — es exactamente lo documentado ("todo compila desde el primer segundo",
nunca promete reutilización entre features) — pero es la única feature de las seis en las
que el cascarón generado se descarta en vez de completarse.

**Propuesta para 1.0.1.** Una opción `--service-from OtroFeature`/`--store-from
OtroFeature` (o simplemente `--no-service`/`--no-store`, dejando el `Logic` generado con
un parámetro `any <Nombre>Servicing` sin resolver y un comentario `// TODO: importa el
protocolo de tu Service compartido`) evitaría el paso "generar → borrar dos ficheros →
editar el resto a mano" en el caso, nada raro, de una feature de solo-lectura sobre datos
que otra feature ya trae.

### 4. La View debe ser dueña de su ViewModel (`@State`): la plantilla usa `let`, y una acción a un ViewModel liberado se pierde sin rastro

**Descripción.** `Templates/View.swift.txt` genera `let viewModel: XxxViewModel` (es lo
que `generate-feature` dejó en las seis vistas de este repo). Cuando el ViewModel es
transitorio y se construye dentro de un builder de destino de navegación
(`CoordinatorView`/`navigationDestination`), SwiftUI reejecuta ese builder durante el
push y sustituye la instancia: la acción `.load` enviada por `.task`/`.onAppear` llega a
la instancia A, A se libera unos milisegundos después (`performLoad` captura `[weak
self]`, así que el trabajo nunca corre y no hay error), y la instancia B que queda en
pantalla nunca recibe `.load`. Resultado: pantalla vacía sin spinner ni error, ~50 % de
las veces en iOS 26.5. Detalle completo y trazas en `INFORME-INTEGRACION.md`, fricción 10.

**Propuesta para 1.0.1.**

1. `Templates/View.swift.txt`: `@State private var viewModel: {{Name}}ViewModel` +
   `_viewModel = State(initialValue: viewModel)` en el `init`. Mismo cambio en los cuatro
   ejemplos y en los snippets de DocC (`ScreenContainer`, arquitectura, guía de 20 min).
2. Documentar la regla en `AGENTS.md`/artículo de arquitectura: "la View es dueña de su
   ViewModel con `@State`; el composition root lo construye, la View lo retiene".
3. `ActionSender` (`ScreenState.sender`): en `DEBUG`, cuando `self` ya es `nil`, emitir un
   `os_log`/`assertionFailure` configurable ("acción X descartada: el ViewModel ya no
   existe") en vez de descartarla en silencio. Lo mismo en el `guard let self else { throw
   CancellationError() }` de `performLoad`/`performActivity`.
4. Opcional: una regla del linter (R12) que marque `let viewModel:` en un fichero `*View.swift`.

---

## CoreNetworking

### 5. Ningún hallazgo que requiera cambiar CoreNetworking

Todo lo usado — `APIService`, `NetworkingConfiguration`, `BaseRequest`/`EndpointService`,
`BearerTokenInterceptor`/`TokenRefreshRetrier`/`TokenRefresher`, `APIError`/`category`,
`MockAPIService`/`InMemoryTransport`/`ManualClock` — se comportó exactamente como
documentado, incluido el pipeline de refresh completo (401 → refresh → reintento) probado
tanto con `InMemoryTransport` (`Core/NetworkingWiringTests.swift`) como contra DummyJSON
real (`AuthIntegrationTests.swift`). La única fricción relacionada con red — la 402
`archlint` reportando ficheros de `CoreNetworking` — es un problema del RECORRIDO de
`archlint` (issue 1, arriba), no del contenido de CoreNetworking.

Si acaso, una mejora menor sin urgencia: `RetryPolicy`'s comportamiento por defecto
(`maxAttempts: 3`, backoff real) se activa también para el `APIService` "en bruto" que
`AuthService` usa para `/auth/login`/`/auth/refresh` — un test de integración que fuerza
un 401/403 en esas rutas puede tardar más de lo esperado por los reintentos exponenciales
antes de que `POST` (no idempotente por defecto) finalmente falle rápido. No bloqueó nada
aquí (documentado, `allowsNonIdempotentRetry` por defecto en `false` evita el reintento en
la práctica), pero conviene mencionarlo en `Retry.md` como algo a tener en cuenta al
componer un `APIService` "de autenticación" sin `retryPolicy: .noRetry` explícito.

---

## Xcode / xcodegen (fuera de AppFoundation/CoreNetworking, para contexto)

No son issues de los paquetes, pero quedan documentadas en
`docs/INFORME-INTEGRACION.md` (fricciones 5-8) porque afectan a cualquiera que integre
AppFoundation/CoreNetworking en un proyecto xcodegen: la necesidad de
`-skipPackagePluginValidation` en `xcodebuild` no interactivo, que un target de Xcode
necesita declarar CADA paquete que importa directamente (no solo el de primer nivel) para
que enlace bajo la acción `test`, y que xcodegen 2.46.0 no soporta referenciar el test
target de un paquete Swift local desde un `scheme`.
