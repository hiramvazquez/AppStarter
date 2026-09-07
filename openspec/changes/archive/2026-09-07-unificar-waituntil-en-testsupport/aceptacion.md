# Aceptación — unificar-waituntil-en-testsupport

Ejecutado el 2026-09-07 siguiendo `.claude/agents/aceptacion.md` del kit.

| criterio | veredicto | evidencia |
|---|---|---|
| `AsyncPolling.swift` define `waitUntil` público, con el porqué | **CUMPLIDO** | `PlatformTestSupport/AsyncPolling.swift:18-27`, con el doc comment que explica por qué se sondea |
| Los dos ficheros de test no definen `waitUntil` e importan el módulo | **CUMPLIDO** | `DiagnosticsViewModelTests.swift:2` y `UploadsViewModelTests.swift:2`; las dos copias privadas borradas |
| `Package.swift` declara `PlatformTestSupport` en `DiagnosticsFeatureTests` | **CUMPLIDO** | `Packages/Features/Package.swift:216` |
| El informe deja de listar `waitUntil`, y los otros cinco grupos siguen igual | **CUMPLIDO** | de 6 grupos a 5; `grep -c waitUntil` sobre el informe → 0 |
| `/kit-verifica` en verde | **CUMPLIDO** | Platform build+tests, Features build+tests, firmado |

**Fuera de alcance, respetado:** `ProductRow` intacto (duplicación deliberada por R13),
`mapError`/`screenError` intactos, ningún test cambia de comportamiento.

**Calidad de lo entregado, comprobado por mutación:** amputado el bucle de sondeo de
`waitUntil`, **siete tests se ponen en rojo** en `DiagnosticsViewModelTests` y
`UploadsViewModelTests`. El helper es carga estructural, no adorno — y los tests que lo usan
distinguen el código bueno del malo.

## Un fuera de alcance, y por qué no se devuelve

El diff **desindexa `.agent-kit/verificacion.txt`**, y ningún criterio lo pedía. Lo cazó la
revisión de scope de este mismo cambio.

Es un defecto real y de los que importan: el marker de verificación entró al repo en
`05b67b8` —el `.gitignore` no alcanza a lo que ya está trackeado— y un marker que viaja
entre máquinas **hace mentir a toda firma futura**: llega con el `sha256` de otro árbol y la
puerta de commit decide sobre un dato ajeno. Es exactamente la maquinaria de la que depende
este cambio para darse por verificado.

Se amplía el acuerdo **por escrito** en `proposal.md` (§ What Changes y un criterio nuevo),
que es la dirección legítima. No se parte en dos cambios porque dejarlo fuera significaría
mantener a propósito una invariante rota en `main` mientras se hace la ceremonia, y porque
son cero líneas de código: un `git rm --cached`.

- [x] `.agent-kit/verificacion.txt` deja de estar trackeado; `git check-ignore` confirma que
      la regla del `.gitignore` ya lo cubre.

## VERDICT: ACEPTADO

Con la ampliación de alcance declarada arriba. Si el owner prefiere el corte estricto, el
`git rm --cached` sale a un cambio propio y este se archiva sin él.
