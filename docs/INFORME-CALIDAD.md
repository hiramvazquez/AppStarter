# Informe de calidad de código — calibración de SwiftLint (PRD-AF-09)

Fecha: 2026-09-03 · SwiftLint 0.65.1 (plugin `SwiftLintPlugins` 0.65.x) · Código: `AppStarterKit`
(36 ficheros en `Sources`, generados por `generate-feature` y completados a mano; tests aparte).

Objetivo: fijar el criterio de calidad del kit (qué bloquea, qué avisa, con qué umbrales) contra
código real antes de convertirlo en la plantilla que `archinit` instalará en cada proyecto.

## 1. Línea base: reglas por defecto de SwiftLint

```
$ swiftlint lint --quiet --reporter json Sources Tests
53 violations en 27 ficheros
  18 Error    identifier_name
  17 Warning  line_length
  11 Warning  identifier_name
   3 Warning  void_function_in_ternary
   3 Warning  legacy_swiftui_aspect_ratio
   1 Warning  function_parameter_count
```

`identifier_name` (29): todos son `c` (`{ c in c.resolve() }` en los Modules) y `vm`
(`performLoad { vm in … }`), los dos idioms del kit. Un default que castiga la convención
documentada no sirve: hay que configurarlo, no aceptarlo tal cual.

## 2. Configuración curada, primera pasada

`only_rules` explícito, severidades por regla, umbrales propuestos y tres reglas regex propias.

```
63 violations
  32 Warning  async_without_await
  16 Warning  line_length
   4 Warning  closure_body_length
   4 Warning  localized_text_literal      (regla propia)
   3 Warning  void_function_in_ternary
   3 Warning  legacy_swiftui_aspect_ratio
   1 Warning  function_parameter_count
```

Clasificación de cada regla con avisos:

| Regla | Avisos | Veredicto | Acción |
|---|---|---|---|
| `async_without_await` | 32 | **Falso positivo estructural.** En esta arquitectura el `async` viene del protocolo (`Servicing`/`Storing`/`Logic`); mocks, actores y previews lo implementan sin `await` por contrato. | Descartada, motivo anotado en el `.yml`. |
| `closure_body_length` | 4 | **Umbral incompatible con SwiftUI.** Los `body` con `ScreenContainer { send in … }` son closures de 33-41 líneas por naturaleza; `type_body_length` y `function_body_length` ya acotan el tamaño real. | Descartada. |
| `localized_text_literal` (propia) | 4 | **Premisa falsa.** `Text("literal")` en SwiftUI ya es `LocalizedStringKey` y se traduce por String Catalog; lo no localizable es `Text(verbatim:)`/`Text(variable)`. | Descartada; queda documentado para no reinventarla. |
| `void_function_in_ternary` | 3 | **Código a mejorar.** `isEmpty ? vm.setEmpty() : vm.setContent()` en tres ViewModels. | Corregido: `if … { } else { }`. |
| `legacy_swiftui_aspect_ratio` | 3 | **Código a mejorar.** `.aspectRatio(contentMode: .fit)` en tres Views. | Corregido: `.scaledToFit()`. |
| `line_length` | 16 | **Código a mejorar.** Llamadas y literales de 121-153 columnas en previews, mocks y tests (comentarios y URLs ya se ignoran). `swift format lint` no reporta longitud, pero `swift format format` sí envuelve. | Corregido con `swift format format -i` y el `.swift-format` del kit (18 ficheros); un nombre de test acortado a mano. |
| `function_parameter_count` | 1 | **Aviso legítimo, excepción justificada.** `makeAuthenticatedAPIService` recibe 7 colaboradores: es el composition root del networking, DI por `init` sin globals; agruparlos en un struct movería los mismos siete nombres. | `// swiftlint:disable:next function_parameter_count` con el motivo en el comentario: así se documenta una excepción, no se baja el umbral para todos. |
| `redundant_optional_initialization` | 0 | Renombrada en 0.65 a `implicit_optional_initialization`. | Nombre nuevo. |

Sin avisos en la primera pasada, y por tanto sin calibrar contra código de verdad todavía:
`force_*`, `implicitly_unwrapped_optional`, `unowned_variable_capture`, `weak_delegate`,
`unhandled_throwing_task`, `private_swiftui_state`, `function_body_length`, `type_body_length`,
`file_length`, `cyclomatic_complexity`, `large_tuple`, `nesting`, `accessibility_*`, y las reglas
propias `no_print_in_production` y `os_log_public_interpolation`. Que no disparen sobre código
generado por el kit es la señal esperada; sus umbrales quedan en los valores propuestos hasta que
un proyecto real los tense.

## 3. Resultado

```
$ swiftlint lint --strict --quiet Sources Tests        → sin salida, exit 0
$ swift package archlint                               → archlint: 0 errors, 0 warning(s) in 37 file(s).
$ swift build                                          → Build complete! (ArchitectureLint + SwiftLint plugins)
$ swift test                                           → Test run with 48 tests in 16 suites passed
```

Prueba negativa (el criterio de aceptación del PRD): un `try!` en `ProfileViewModel.handle`.

```
$ swift build
Sources/AppStarterKit/Features/Profile/ProfileViewModel.swift:34:22: error: Force Try Violation: Force tries should be avoided (force_try)
error: failed: PrebuildCommand(… displayName: "SwiftLint" …)
```

Revertido, `Build complete!` de nuevo. El mismo mecanismo que `ArchitectureLint`: un comando del
grafo de build que sale con código distinto de 0 es un fallo de build, y el diagnóstico con
`ruta:línea:col: error:` es navegable en Xcode.

## 4. Lo que pasa al kit (AppFoundation 1.1.0)

- `AppStarterKit/.swiftlint.yml` tal cual es `Templates/swiftlint.yml`; `archinit` lo copia.
- Las tres reglas descartadas y sus motivos van en el propio fichero para que nadie las
  reintroduzca sin leerlos.
- `verify-generator.sh` y los cuatro ejemplos pasan `swiftlint --strict` con la plantilla, para
  que el generador nunca produzca código que su propio linter rechace.
- Pendiente de calibrar con proyectos reales: los umbrales de tamaño y complejidad (aquí no se
  tensaron) y la utilidad de `accessibility_label_for_image`/`accessibility_trait_for_button`.
