## Context

Ver `proposal.md` — «Why» para el motivo y los tres fallos medidos.

Lo que condiciona el diseño:

- Los dos `Package.swift` compilan con `.defaultIsolation(MainActor.self)`,
  `.enableUpcomingFeature("InferIsolatedConformances")` y
  `.enableUpcomingFeature("NonisolatedNonsendingByDefault")`. Una declaración sin anotar
  queda **aislada al MainActor**; eso no cambia en este cambio.
- AppFoundation se compila con los mismos ajustes, y ahí `AppErrorConvertible` y
  `ScreenError` ya están marcados `nonisolated`. `DomainError`, entre medias, no lo está.
- Swift 6.3.3 tragaba esa inconsistencia; Swift 6.4 no. El repo no la había visto nunca.
- El `archlint` R13 y el resto de reglas de arquitectura no entran aquí: ningún import
  cambia.

## Goals / Non-Goals

**Goals:**

- Que el arreglo quede en el sitio donde está la causa, no donde se manifiesta el síntoma.
- Que una feature nueva escrita mañana no tenga que repetir ninguna anotación de este cambio.
- Que el fallo de toolchain se diagnostique en un minuto la próxima vez.

**Non-Goals:**

- Revisar el modelo de aislamiento de los paquetes. `defaultIsolation(MainActor)` se queda.
- Anotar `nonisolated` de forma preventiva en protocolos que hoy nadie implementa con un
  `actor`. La regla del spec es «tiene un conformante `actor`», no «podría tenerlo».

## Decisions

### 1. `DomainError` se arregla en AppFoundation, no aquí

`DomainError` es el que está mal: sus dos vecinos en el mismo paquete
(`AppErrorConvertible`, `ScreenError`) ya son `nonisolated`, y su propio comentario de
documentación dice que el tipo «cruza de un `Logic` `nonisolated` de vuelta a un `ViewModel`
`@MainActor`». Le falta la anotación que describe lo que ya declara hacer.

Comprobado el 2026-09-15 parcheando el checkout de `.build` y reconstruyendo: marcando el
protocolo y su `extension` como `nonisolated`, los **once** tipos de error de dominio del
repo compilan sin tocar ninguno.

*Alternativa descartada:* anotar los once tipos aquí. Funciona —también lo medí— pero deja
el despiste vivo upstream, obliga a repetir la anotación en cada feature nueva, y se la come
igual cualquier otro proyecto que consuma el kit.

*Coste:* este cambio no se puede cerrar hasta que AppFoundation 1.3.2 esté publicada. Es un
bloqueo real y está declarado como prerrequisito en `proposal.md`.

### 2. `TransportMappable` se anota en el protocolo **y** en su `extension`

`TransportMappable` hereda de `DomainError` y aporta `from(_:)` e `isRetryable` por defecto
en una `public extension`. Anotar solo el protocolo no basta: los miembros de la `extension`
siguen siendo MainActor y el aislamiento vuelve a entrar por ahí, de forma que cada
conformante tiene que anotarse a mano.

Con la `extension` también `nonisolated`, los dos enums de
`Packages/Platform/Tests/NetworkingTests/TransportMappableTests.swift` dejan de necesitar
anotación —lo verifiqué revirtiéndolos y reconstruyendo en verde—, y con ellos el resto de
conformantes. Por eso el spec lo pide como regla y no solo para este protocolo.

### 3. `CameraCapturing` queda `nonisolated`; el picker salta al MainActor por dentro

Es el único punto con trabajo real. `CameraCapturing` tiene hoy cuatro conformantes:
`CameraKitCapture` y `SimulatedCamera` (structs normales), `DeviceCameraCapture`
(`@MainActor`, presenta un `UIImagePickerController`) y `CameraCapturingMock` (un `actor`,
en `Packages/Features/Tests/UploadsFeatureTests/Mocks/UploadsServiceMock.swift`). Con el
protocolo sin anotar el `actor` no conforma; con el protocolo `nonisolated` el que rompe es
`DeviceCameraCapture`, con `main actor-isolated class method 'isSourceTypeAvailable' cannot
be called from outside of the actor`.

Se elige **`nonisolated`**, dejando a `DeviceCameraCapture` la responsabilidad de entrar al
MainActor donde toca UIKit: un método privado `@MainActor` con el cuerpo actual, y un
`capturePhoto()` `nonisolated` que lo espera. `ImagePickerCoordinator` se queda `@MainActor`
tal cual está.

La forma queda alineada con los otros seis protocolos del cambio, y con la regla general:
el contrato no impone dónde vive la implementación, la implementación declara lo que
necesita.

*Alternativa descartada:* marcar `CameraCapturing` como `@MainActor` explícito y convertir
`CameraCapturingMock` en un tipo `Sendable` con cerrojo. Toca menos código de producción,
pero rompe la convención del repo —los dobles de Store/Service son `actor`s— y deja a
`CameraCapturing` como el único `*Capturing`/`*Storing` aislado al MainActor, que es
justo la asimetría que nos ha costado esta sesión entender.

*Medido:* al marcar el protocolo `nonisolated`, el único error que aparece en todo el repo
es el de `isSourceTypeAvailable`. `SimulatedCamera` —que también toca UIKit
(`UIGraphicsImageRenderer`, `UIColor`)— compila sin cambios.

### 4. `SessionExpiring` se queda sin anotar

Su único conformante, `AppSessionState`, es `@MainActor` de verdad: muta
`bannerOnNextLogin` y llama a `router.setRoot(.login)`. Anotarlo `nonisolated` no arregla
nada, mueve el error al conformante (`main actor-isolated property 'bannerOnNextLogin' can
not be mutated from a nonisolated context`). Lo probé. De ahí el tercer escenario del
requisito nuevo: la regla tiene que decir también cuándo **no** anotar, o el siguiente que
la lea anotará todo lo que sea `Sendable`.

### 5. El generador de AppFoundation entra en el alcance (ampliación acordada el 2026-09-15)

**Esto no estaba en el acuerdo original. Se añade por escrito porque apareció al implementar.**

Al correr la lista de CI de AppFoundation sobre el arreglo de la decisión 1,
`Scripts/verify-generator.sh` falla sobre el código que el propio generador emite:

```
DemoAppTests/Features/Products/Mocks/ProductsServiceMock.swift:12:7: error:
actor 'ProductsServiceMock' cannot conform to global-actor-isolated protocol 'ProductsServicing'
```

Las plantillas `Templates/Service.swift.txt`, `Templates/Store.swift.txt` y
`Templates/Logic.swift.txt` declaran `{{Feature}}Servicing`/`{{Feature}}Storing: Sendable` sin
`nonisolated`, mientras `Templates/ServiceMock.swift.txt` genera un `actor`. Es exactamente el
caso que el requisito nuevo de `specs/plataforma/spec.md` describe — y el generador lo
incumple en cada feature que produce.

Entra en el alcance porque `AGENTS.md` de este repo manda crear las features nuevas con
`generate-feature`: sin esto, la primera feature que se genere en AppStarter después de la
1.3.2 nace sin compilar, y el requisito que acabamos de escribir sería falso el día que se
archive.

*Alternativa descartada:* publicar 1.3.2 solo con `DomainError` y dejar el generador para
después. Desbloquea igual a AppStarter hoy, pero deja el repo en un estado donde la regla
escrita y la herramienta que genera el código se contradicen.

*Segunda ampliación, mismo día:* arreglada la plantilla, `verify-generator.sh` llegaba hasta
su último paso —la sonda que rompe `LoginViewModel` a propósito para comprobar que
ArchitectureLint caza una violación de R1— y moría ahí. La inyección añade
`private let api: APIService?`, un `let` opcional sin valor: con Swift 6.4 el compilador
corta antes con `class 'LoginViewModel' has no initializers` y el diagnóstico `[ArchLint.R1]`
nunca se emite, así que la sonda dejaba de medir R1 para medir un error de compilación
cualquiera. Se le pone `= nil` (`Scripts/verify-generator.sh:187`): la violación sigue siendo
el `import CoreNetworking` y el `APIService` dentro de un ViewModel, que es lo que R1
persigue. Entra porque sin ella no hay forma de saber si ArchitectureLint sigue protegiendo
R1 bajo el toolchain nuevo — y eso sí afecta a AppStarter, que depende de esa protección.
No se pudo comprobar si la sonda ya fallaba antes del cambio: la ejecución de referencia
moría mucho antes, en la generación, así que queda como defecto observado y no como causa
confirmada.

*Lo que sigue fuera:* los 7 protocolos de `Examples/*/Sources` (`NotesApp`, `LoginApp`,
`CatalogApp`). Estaban rotos bajo Swift 6.4 **antes** de este cambio —con el código original
fallaban en `conformance of 'LoginError' to 'AppErrorConvertible' crosses…`, el bug de la
decisión 1— así que ni son una regresión nuestra ni bloquean a AppStarter. Son un cambio
propio de AppFoundation.

## Risks / Trade-offs

- **El cambio depende de publicar AppFoundation 1.3.2** → Es un bloqueo aceptado, no un
  riesgo a mitigar: sin él los once tipos de error siguen rotos. Las tareas lo ponen
  primero, y hasta que exista el resto del cambio no se puede verificar de punta a punta.
  El repo de AppFoundation no está clonado en esta máquina.
- **El salto al MainActor añade una suspensión en el camino de la cámara** → Irrelevante en
  la práctica: el trabajo que sigue es presentar un `UIImagePickerController` y esperar a que
  la persona haga una foto.
- **`DeviceCameraCapture` solo se compila en device** (`#if os(iOS)` y no simulador), así que
  `swift build` de `Packages/Platform` —que apunta a macOS— nunca lo ve → Por eso el criterio
  de aceptación exige el `xcodebuild` de la app contra un simulador de iOS 27: es el único
  comando que compila esa rama.
- **Cambiar el toolchain global de swiftly afecta a otros proyectos de la máquina** → Es una
  decisión del entorno de quien desarrolla, no del repo. `AGENTS.md` documenta el requisito y
  el síntoma; quien prefiera un `.swift-version` por proyecto tiene la información para
  hacerlo.
- **El requisito nuevo se puede leer como «anota todo lo `Sendable`»** → Mitigado con el
  tercer escenario y con el caso `SessionExpiring` escrito arriba.

**Corregido por la enmienda del 2026-09-15 de `proposal.md`:** los dos riesgos de la cámara de
esta lista están mal medidos. El salto al MainActor se **elimina**, no se añade; y `#if os(iOS)`
también es cierto en el simulador, así que el `xcodebuild` contra simulador no compila la rama
de `DeviceCameraCapture`. Allí está lo que sí la verifica.

## Migration Plan

1. Arreglar `DomainError` **y las plantillas del generador** en AppFoundation (decisiones 1 y
   5) y publicar `1.3.2`. Sin esto no se puede verificar nada de lo demás.
2. Subir el suelo en los tres manifiestos y resolver.
3. Anotar los siete protocolos y la `extension` de `TransportMappable`.
4. `DeviceCameraCapture`: método privado `@MainActor` y `capturePhoto()` `nonisolated`.
5. Documentar el toolchain en `AGENTS.md`.
6. Verificar los dos paquetes y el `xcodebuild` de la app contra iOS 27.

No hay estrategia de rollback más allá de `git revert`: el cambio no toca datos, ni
persistencia, ni formato de red.
