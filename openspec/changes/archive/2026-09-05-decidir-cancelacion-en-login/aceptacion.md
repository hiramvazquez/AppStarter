# Aceptación — decidir-cancelacion-en-login

Ejecutado el 2026-09-05 siguiendo `.claude/agents/aceptacion.md`.

| criterio | veredicto | evidencia |
|---|---|---|
| La spec tiene un escenario que dice qué le pasa a un login en vuelo cuando su pantalla se elimina, con la razón escrita | **CUMPLIDO** | `specs/plataforma/spec.md` → `#### Scenario: Un login en vuelo pierde su pantalla`, con THEN/AND y el párrafo de la decisión. Aterriza en la spec viva al archivar |
| `LoginView.swift` coherente: sin el parámetro, la razón en la spec | **CUMPLIDO** | `LoginView.swift:19` → `ScreenContainer(viewModel)`, sin `cancelsInFlightWorkOnRemoval` |
| `Scripts/verifica.sh` en verde | **CUMPLIDO** | Platform build+tests, Features build+tests, firmado contra el diff |

**Fuera de alcance respetado:** el diff toca dos ficheros, los dos dentro de la carpeta del
cambio. Ni las otras nueve pantallas ni el default del kit.

**Lógica repetida:** el informe sigue marcando los seis cuerpos que ya existían antes de
este cambio (`mapError()` ×5, `screenError()` ×2, un `body()` ×3). **Este cambio no añade
ninguno** — no es código. Quedan como deuda conocida, no como hallazgo de esta aceptación.

## VERDICT: ACEPTADO

Nota sobre la forma de este cambio: no toca código y eso es correcto, no un descuido. La
decisión era **mantener el comportamiento actual**, y lo que faltaba no era código sino que
alguien lo decidiera y lo escribiera. Antes el login se cancelaba por accidente —porque
nadie miró el default—; ahora se cancela por decisión, con la razón al lado. El
comportamiento es idéntico; lo que cambia es que deja de ser una casualidad.
