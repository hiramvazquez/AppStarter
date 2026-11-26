## 1. Los tests del fallo, vistos en rojo contra el código de hoy

- [x] 1.1 En `Packages/Features/Tests/LoginFeatureTests/LoginViewModelTests.swift`, sustituir
      `loginFailureSurfacesError` —el test que hoy fija el defecto— por «un login rechazado
      deja el formulario a la vista»: `mock.errorToThrow = LoginError.invalidCredentials`,
      usuario `emilys`, y tras el envío exige `mock.logins.calls == ["emilys"]`,
      `hasError == false`, `isIdle`, `isPerformingActivity == false`,
      `banner?.message == LoginError.invalidCredentials.screenError.message`,
      `username == "emilys"` y `router.mainStack.root == .login`. De momento espera
      `inFlightLoad`, como el resto del fichero (design §4).
      Verificación: el test existe con esas siete exigencias.
      **Hecho (2026-11-25):** `loginRechazadoDejaElFormulario`. Las siete exigencias viven en
      un ayudante privado, `exigirFormularioALaVista(tras:usuario:)`, que comparte con la 1.2:
      dos tests con el mismo cuerpo los habría marcado el detector de lógica repetida.
- [x] 1.2 Añadir «un campo vacío sale por el mismo camino que el rechazo»: igual que el
      anterior con `LoginError.emptyUsername` y su `screenError.message`.
      Verificación: el test existe.
      **Hecho (2026-11-25):** `campoVacioSalePorElMismoCamino`, sobre el mismo ayudante. Una
      diferencia con «igual que el anterior»: el usuario va vacío (`""`), que es el caso que
      nombra, así que exige `mock.logins.calls == [""]` y `username == ""`.
- [x] 1.3 Añadir «tras un fallo, un segundo intento entra»: mismo view model, un primer
      `.login` con `errorToThrow = LoginError.invalidCredentials`, después
      `mock.errorToThrow = nil` y un segundo `.login`; exige `router.mainStack.root == .products`
      y `mock.logins.calls.count == 2`. **Este no tiene que estar rojo hoy** (design §4): se
      añade como regresión.
      Verificación: el test existe.
      **Hecho (2026-11-25):** `segundoIntentoTrasUnFallo`.
- [x] 1.4 **La premisa.** `cd Packages/Features && swift test --filter LoginViewModelTests`
      contra el `LoginViewModel.swift` sin tocar. Verificación: 1.1 y 1.2 **fallan**, y fallan
      en `hasError == false`, en `isIdle` y en `banner?.message` —las tres que dependen de que
      la fase no se mueva—; sus otras exigencias, 1.3 y el resto del fichero pasan. Se anotan
      aquí las líneas literales de los fallos. Si 1.1 o 1.2 pasan, o fallan en otra exigencia,
      los tests no miran lo que dicen: se para y se anota, no se toca `login()`.
      **Resultado (2026-11-25, Swift 6.4):** se cumple. `swift test` exit 1,
      `Test run with 8 tests in 1 suite failed after 0.013 seconds with 6 issues.` Las seis
      incidencias son tres por test, las mismas en los dos:
      `LoginViewModelTests.swift:59:9: Expectation failed: viewModel.hasError == false`,
      `:60:9: Expectation failed: viewModel.isIdle` y
      `:62:9: Expectation failed: viewModel.banner?.message == error.screenError.message`.
      Sus otras cuatro exigencias —`logins.calls`, `isPerformingActivity == false`, `username`
      y la raíz en `.login`— no dan incidencia. 1.3 pasa, como estaba previsto, y pasan los
      otros cinco tests del fichero.

## 2. El envío cambia de primitiva

- [x] 2.1 `Packages/Features/Sources/LoginFeature/LoginViewModel.swift`, método `login()`:
      `performLoad { vm in` pasa a `performActivity(errorHandling: .banner) { vm in`, y en la
      rama `catch LoginError.cancelled` `vm.setIdle()` pasa a `vm.stopActivity()`, con la misma
      guarda `if !Task.isCancelled`. El comentario de esa rama (líneas 76-79) se reescribe para
      que hable de la actividad y del indicador, no de `performLoad` ni de `.loading`.
      Verificación:
      `grep -cE "performLoad *[({]|setIdle" Packages/Features/Sources/LoginFeature/LoginViewModel.swift`
      devuelve `0`, y `git diff` de ese fichero no toca nada fuera de `login()`.
      **Hecho (2026-11-25):** el `grep` devuelve `0`; `git diff --stat` da `12 insertions(+),
      6 deletions(-)` en tres trozos, los tres dentro de `login()`: la llamada, la rama de
      cancelación y un comentario de documentación nuevo sobre el método, que dice por qué el
      envío no va por la primitiva de carga. Ese comentario no estaba en la tarea; se añade
      porque el patrón viejo viene del ejemplo de referencia del kit y sin el porqué escrito
      vuelve.
- [x] 2.2 En el mismo paso, `LoginViewModelTests.swift` deja de esperar una `Task` que ya no
      existe: todo `inFlightLoad` pasa a `inFlightActivity`. Y los tres tests que leían la fase
      leen la actividad: `loginRoutesToProducts` cambia `phase == .content` por
      `isPerformingActivity == false`; `loginCancelado` cambia `isLoading == false` por
      `isPerformingActivity == false` y conserva `hasError == false` e `isIdle`;
      `loginSuperadoNoResetealaGanador` cambia `isLoading` por `isPerformingActivity`. Sus
      comentarios que nombran `.loading` o `performLoad` se ponen al día.
      Verificación: `grep -c inFlightLoad Packages/Features/Tests/LoginFeatureTests/LoginViewModelTests.swift`
      devuelve `0`.
      **Hecho (2026-11-25):** siete `inFlightLoad` sustituidos, el `grep` devuelve `0`, y en
      el fichero no queda ningún `isLoading`, `.loading` ni `phase ==`.
- [x] 2.3 `cd Packages/Features && swift test --filter LoginViewModelTests`. Verificación:
      todos pasan, incluidos 1.1 y 1.2, que en la 1.4 fallaban. Se anota aquí la última línea
      (`Test run with N tests … passed`).
      **Resultado (2026-11-25):** exit 0,
      `✔ Test run with 8 tests in 1 suite passed after 0.007 seconds.`
      Comprobación añadida, fuera de lo pedido: los dos tests de cancelación cambiaron de
      `isLoading` a `isPerformingActivity`, así que se mutó `login()` dos veces para verlos
      rojos. Sin `vm.stopActivity()` cae «un login cancelado…» (`:108`, 1 incidencia); con
      `vm.stopActivity()` sin la guarda `if !Task.isCancelled` cae «un login superado…» (`:139`,
      1 incidencia). El fichero se restauró idéntico (mismo sha256) y la suite volvió a
      `8 tests … passed`.

## 3. En la app de verdad

- [x] 3.1 Compilar la app del cambio (`xcodebuild build`, con el esquema, el destino y los
      flags de `kit.conf`) y lanzarla en un simulador que no sea el que el owner tenga en uso.
      Recién arrancada, un toque en «Iniciar sesión» con el formulario vacío.
      Verificación: el formulario sigue en pantalla y se ve el banner «Introduce tu nombre de
      usuario.» —hoy ese toque deja «Falta el usuario» a pantalla completa—. Captura anotada.
      **Resultado (2026-11-25):** `xcodebuild build … CODE_SIGNING_ALLOWED=NO -quiet` exit 0
      en 13 s; el `AppStarter.debug.dylib` pasa de sha256 `e6279ae6…` a `def91ad2…`. Lanzada
      en el iPhone 17 · iOS 26.5 (`BC502CFF…`, que no es el del owner), PID 88725. Un toque en
      «Iniciar sesión» con el formulario vacío: siguen en pantalla «Credenciales», los campos
      Usuario y Contraseña y el botón, y arriba sale el banner rojo «Introduce tu nombre de
      usuario.». Visto en la captura, además: mientras dura, el banner tapa la fila «Usuario
      de prueba: emilys / emilyspass»; se retira solo a los pocos segundos.
- [x] 3.2 En esa misma sesión de la app, teclear 6 + 10 caracteres de relleno —no las
      credenciales de prueba— y enviar; cuando responda, tocar «Iniciar sesión» otra vez.
      Verificación: tras el `400` el formulario sigue visible con el usuario tecleado y el
      banner «Comprueba tu usuario y contraseña.»; y en
      `xcrun simctl spawn <udid> log show --last 5m --predicate 'process == "AppStarter" AND subsystem == "com.apple.CFNetwork" AND eventMessage CONTAINS "sent request"'`
      hay **dos** líneas con el mismo PID. Captura y las dos líneas, anotadas aquí.
      Nota de herramienta: en estos simuladores la acción `text` no entra («does not take a
      paste from the Mac»); se teclea con el teclado en pantalla (`set_keyboard show`) y se
      deja en `hide` al terminar.
      **Resultado (2026-11-25):** se cumple. Con `asdfgh` + diez teclas, tras el `400` la
      captura enseña el formulario entero —`asdfgh`, diez puntos en Contraseña, el botón— y el
      banner «Comprueba tu usuario y contraseña.». Un segundo toque en «Iniciar sesión», sin
      relanzar, lanza otra petición en el mismo proceso:
      `17:45:25.900 AppStarter[88725:…] … sent request, body S 63` y
      `17:45:32.009 AppStarter[88725:…] … sent request, body S 64`, las dos con respuesta `400`.
      **Hallazgo, fuera de lo que esta tarea pedía, y no se arregla aquí:** esos dos tamaños
      no deberían diferir. 6 + 10 son 64 bytes; el primer envío salió con 63 y el segundo, sin
      teclear nada más, con 64 — y la captura tomada tras el primero ya enseñaba los diez
      puntos. Repetido a propósito en la misma sesión: una tecla y envío inmediato → 65 de 65
      (bien, y su reenvío 65); otra ráfaga de diez teclas y envío inmediato → **68 de 75**. No
      se pierde ninguna pulsación: acaban llegando y el reenvío las lleva. Pero un toque en el
      botón puede adelantarse a pulsaciones que el teclado en pantalla todavía está
      entregando, y la petición sale con el valor de un instante antes. Provocado a velocidad
      de máquina (toques inyectados uno tras otro); con una sola tecla no ocurrió. `login()`
      lee `vm.username`/`vm.password` en el mismo punto antes y después de este cambio, y
      `LoginView` no confirma el texto antes de enviar (ni `@FocusState` ni `onSubmit`), así
      que la carrera no la introduce el cambio — leído, no medido con la compilación anterior.
      Corrige una frase del `proposal.md` (anotado allí). Si explica los dos envíos de 63
      bytes del owner, no se sabe: él tecleaba con el teclado del Mac, que aquí no se pudo
      inyectar.

## 4. Cierre

- [x] 4.1 `git status` y `git diff --stat`. Verificación: el cambio toca `LoginViewModel.swift`,
      `LoginViewModelTests.swift` y `openspec/changes/un-login-fallido-deja-el-formulario-a-la-vista/`.
      Nada más. Los doce borrados de `.claude/` siguen en el árbol sin stagear: se stagea por
      nombre de fichero, nunca con `git add -A`.
      **Resultado (2026-11-25):** `git diff --stat` da `2 files changed, 73 insertions(+),
      25 deletions(-)` —`LoginViewModel.swift` (18 líneas) y `LoginViewModelTests.swift`
      (80)—, y el único directorio nuevo es el de este cambio, con sus cinco ficheros. Ningún
      otro fichero versionado cambia. Los doce borrados de `.claude/` siguen sin stagear.
- [x] 4.2 Stagear por nombre, `/kit-verifica` y `/kit-revisa`. Verificación: la firma verde y
      el revisor sin hallazgos que bloqueen; se anotan aquí el `verificado:` de la firma y el
      veredicto.
      **Resultado (2026-11-25, kit 2.4.1):** stageados por nombre los dos `.swift` y el
      directorio del cambio; ningún borrado de `.claude/` en el índice. Firma
      `verificado: 2026-11-25T23:50:33Z`, `diff: fc142af1…`, `resultado: verde`,
      `toolchain: Swift 6.4 · Xcode 27.0`; los diez pasos en ✅ —`secretos`, `ATS`,
      `SwiftLint · --strict`, los dos `swift-format`, build y tests de los dos paquetes y
      `App · build + AppTests + AppSnapshotTests`— en 83 s, y
      `✅ sin lógica repetida que toque este cambio (166 ficheros Swift mirados)`. El kit avisa
      `⚠️  ÁRBOL SUCIO` por los doce borrados de `.claude/`, que no son Swift ni de este cambio.
      `/kit-revisa`: **GREEN**, sin hallazgos, ronda 1 de un presupuesto de 2; punto marcado.
      El revisor comprobó por lectura que ningún test de `AppUITests`, `AppTests` ni
      `AppSnapshotTests` espera el título del error, la pantalla de error del login ni
      `phase == .content`; que nadie lee la fase de `LoginViewModel` fuera de sus tests; que
      el banner de error (4 s) y el de sesión caducada no se pisan mal; y que la rama de
      cancelación cumple la cláusula 4. Sobre la carrera de la 3.2: el cambio la deja igual
      —las dos primitivas leen los campos en el mismo punto— y está bien dejada fuera.
      Dos notas suyas, sin acción: si el primer envío de dos termina bien pese a haber sido
      cancelado, su cierre llega a `startSession()` (ya pasaba antes del cambio); y `rodaja.sh`
      contó `1522 líneas de cambio` porque diffea el árbol y mete los doce borrados ajenos.
- [x] 4.3 `/kit-verifica` en verde sobre el árbol final, con todas las anotaciones de este
      fichero ya escritas y stageadas: anotar aquí invalida la firma de la 4.2, así que esta
      es la pasada que deja entrar el commit. Verificación: `resultado: verde` en
      `.agent-kit/verificacion.txt` y la puerta de commit deja pasar. Esta casilla se marca
      antes de esa pasada —marcarla después volvería a invalidarla—; si sale roja, se desmarca.
      **Corrección (2026-11-25, al implementar; el texto de arriba se deja como se acordó).**
      Dos de sus frases son falsas con el kit instalado, la 2.4.1: «anotar aquí invalida la
      firma de la 4.2» y «marcarla después volvería a invalidarla». Desde la 2.2.0 la firma
      cubre el árbol salvo `openspec/`, y está comprobado aquí: con `proposal.md` y `tasks.md`
      editados después de firmar, `.git/hooks/pre-commit` devuelve `0`. La tarea se escribió
      con la regla de septiembre (kit 2.0.0). La pasada se hace igual, porque es lo que la
      tarea y la norma del proyecto piden, y la casilla se marca después de verla en verde.
      **Resultado (2026-11-25):** exit 0 en 62 s, los diez pasos en ✅ y
      `✅ verde · toolchain: Swift 6.4 · Xcode 27.0 · firmado contra el árbol verificado`.
      Firma `verificado: 2026-11-25T23:56:10Z`, `resultado: verde`, y el mismo
      `diff: fc142af1…` que la pasada de la 4.2: las anotaciones no movieron lo firmado.
      `.git/hooks/pre-commit` devuelve `0`. No se ha commiteado: lo decide el owner.

## Workflow follow-up

- El commit pasa por la puerta del kit. El push lo decide el owner: se para y se pregunta.
- Tras el push, el job `App (xcodebuild test: unit + snapshot + UI, offline)` del CI sobre ese
  commit es la única prueba de que los `XCUITests` siguen cruzando el login. Si alguno falla
  ahí, se anota el test y el mensaje y se decide; no se improvisa sobre el cambio.
- El login bueno de punta a punta —`emilys` / `emilyspass` en la app— lo confirma el owner en
  su simulador. El pipeline ya lo cubre `AuthIntegrationTests`.
- Archivar, con `/kit-revisa` pasado: el delta crea `openspec/specs/inicio-de-sesion/spec.md`.
