# Unificar `waitUntil` en PlatformTestSupport

## Why

`Scripts`/`kit-duplicados` reporta `waitUntil(timeout:_:)` **idéntico** en dos targets de
test — `DiagnosticsFeatureTests/DiagnosticsViewModelTests.swift:104` y
`UploadsFeatureTests/UploadsViewModelTests.swift:79`. Mismo cuerpo, misma firma, y hasta el
doc comment del segundo dice *"same rationale as `DiagnosticsViewModelTests`"*: la segunda
copia se escribió mirando la primera.

`PlatformTestSupport` existe **exactamente para esto**. Lo dice su propio comentario en
`Packages/Platform/Package.swift:25-28`: *"mocks/spies compartidos por más de un
`*FeatureTests`"*. El helper cumple el criterio y no está allí.

No es una limpieza cosmética: la próxima feature que necesite esperar por estado observable
escribirá una tercera copia, porque no hay nada que le diga dónde está la primera.

## What Changes

- Nace `Packages/Platform/Sources/PlatformTestSupport/AsyncPolling.swift` con `waitUntil`
  público.
- `DiagnosticsFeatureTests` gana la dependencia `PlatformTestSupport` en
  `Packages/Features/Package.swift` (`UploadsFeatureTests` ya la tiene).
- Las dos copias privadas se borran y sus ficheros importan `PlatformTestSupport`.
- Se escribe el contrato en la spec: dónde vive un helper que necesita más de un target de
  test.
- **Añadido tras la revisión de scope** (ver `aceptacion.md`): `.agent-kit/verificacion.txt`
  deja de estar trackeado. Entró al repo en `05b67b8` y un marker de verificación que viaja
  entre máquinas hace mentir a toda firma futura.

## Fuera de alcance

- **`ProductRow`**, duplicado en tres vistas. Investigado en este mismo cambio: es
  **deliberado y está documentado** — una `*Feature` no puede importar otra (R13), y un
  módulo de UI compartido para una fila no compensa. No se toca.
- **`mapError`/`screenError`**, duplicados entre `*Logic`. Unificarlos obligaría a que
  `Domain` —que hoy no depende de nada— conociera `CoreNetworking`, o a añadir dependencias
  de módulo a dos features por siete líneas. La cura es peor. No se toca.
- Cambiar el comportamiento de ningún test. Es un movimiento de código, no un cambio de
  cobertura.

## Criterios de aceptación

- [ ] `Packages/Platform/Sources/PlatformTestSupport/AsyncPolling.swift` define
      `waitUntil(timeout:_:)` público, con el porqué de sondear en vez de esperar un `Task`.
- [ ] `DiagnosticsViewModelTests.swift` y `UploadsViewModelTests.swift` **no** definen
      `waitUntil`, e importan `PlatformTestSupport`.
- [ ] `Packages/Features/Package.swift` declara `PlatformTestSupport` en las dependencias
      de `DiagnosticsFeatureTests`.
- [ ] El informe de duplicados **deja de listar** `waitUntil`, y los otros cinco grupos
      siguen igual — este cambio no arregla ni rompe ninguno.
- [ ] `/kit-verifica` en verde: los mismos tests que pasaban antes pasan después.
- [ ] `.agent-kit/verificacion.txt` no está trackeado, y `git check-ignore` confirma que la
      regla del `.gitignore` lo cubre.
