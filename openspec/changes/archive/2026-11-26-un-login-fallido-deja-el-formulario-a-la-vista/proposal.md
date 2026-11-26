# Un login fallido deja el formulario a la vista

## Why

Un inicio de sesión rechazado deja la pantalla de login en un callejón sin salida: el
formulario desaparece, queda «Credenciales inválidas / Comprueba tu usuario y contraseña.» a
pantalla completa, sin botón, y la única forma de volver a intentarlo es matar la app.

**Medido el 2026-11-25**, con la compilación de `898b542` (sha256 de `AppStarter.debug.dylib`
`e6279ae6…`) en un iPhone 17 · iOS 26.5: se teclean 6 + 10 caracteres de relleno, `POST
/auth/login` responde `400`, y la pantalla queda sin formulario ni botón, con el teclado
todavía desplegado sobre una pantalla que ya no tiene ningún campo.

**Así se encontró.** El owner no podía entrar. En el log de CFNetwork de su simulador hay dos
intentos, a las 16:57:32 y a las 16:58:09, **en dos procesos distintos** (78012 y 84384): tuvo
que relanzar la app para poder probar la segunda vez. Los dos mandaron un cuerpo de 63 bytes;
con `emilys` / `emilyspass` son 64. Un carácter de menos bastó para quedarse fuera, porque la
pantalla no deja corregirlo.

**Lo que NO está roto, medido el mismo día**, para que nadie lo busque ahí:

- DummyJSON y el pipeline: `INTEGRATION=1 swift test --filter AuthIntegrationTests` →
  `Test run with 2 tests in 1 suite passed`. El login bueno manda 64 bytes y recibe `200`.
- El formulario no pierde caracteres: 6 + 10 tecleados → `sent request, body S 64`.

  **Corrección (2026-11-25, al implementar; la frase de arriba se deja como se acordó).**
  Esa medida se hizo con una pausa entre la última tecla y el botón, y solo vale así. En la
  tarea 3.2, con una ráfaga de diez teclas y el envío inmediato, la petición salió con 63
  bytes de 64, y en una repetición con 68 de 75: el toque en el botón se adelantó a
  pulsaciones que aún no habían llegado al view model. No se pierden —el reenvío las lleva—,
  pero «no pierde caracteres» no equivale a «lo que se envía es lo que se ve». Es un defecto
  distinto del de este cambio y queda fuera de él; el detalle está en `tasks.md`, tarea 3.2.

**La causa.** `LoginViewModel.login()` envía con `performLoad`
(`Packages/Features/Sources/LoginFeature/LoginViewModel.swift:68`). Cuando el trabajo de un
`performLoad` falla, la fase pasa a `.error`, y con esa fase el contenedor de pantalla oculta
el contenido entero (`ScreenPresentationLogic.hidesContent`, AppFoundation 1.4.2). El botón de
reintentar solo existe si el error es reintentable (`App/AppErrorPresenter.swift:30`), y
`LoginError.invalidCredentials` no lo es. Tampoco `emptyUsername` ni `emptyPassword`: recién
arrancada la app, un solo toque en «Iniciar sesión» con el formulario vacío deja la pantalla en
«Falta el usuario / Introduce tu nombre de usuario.», sin formulario y sin llegar a la red.
Medido el mismo día con la misma compilación; es la reproducción más corta. Con la contraseña
vacía el camino es el mismo en el código y no se ha reproducido aparte.

`performLoad` es la primitiva de una pantalla que **carga** su contenido: si la carga falla no
hay nada que enseñar. Un formulario es lo contrario: el contenido ya está, y es lo que el
usuario necesita para corregir. El propio kit lo dice de `performActivity` («Ideal for refresh,
pagination, form submit…», `LoadableViewModel.swift:170`), y este repo ya lo hace así en
`CartViewModel.edit`.

**Por qué no se vio.** El defecto está fijado por un test:
`LoginViewModelTests.loginFailureSurfacesError` exige `hasError` tras un login rechazado. Y en
modo offline `App/OfflineFixtures.swift` responde `200` a `auth/login` sin mirar las
credenciales, así que ningún `XCUITest` ha recorrido nunca el camino del rechazo.

## What Changes

- `LoginViewModel.login()` deja de enviar con `performLoad` y pasa a `performActivity` con el
  error en banner. Un fallo —del servidor o de la validación local— deja el formulario donde
  estaba, con lo tecleado, y enseña el mensaje encima.
- La rama de cancelación de ese método sigue cumpliendo la cláusula 4 del requisito de
  `plataforma` («Una cancelación que se lanza no se le presenta al usuario como error»), ahora
  sobre la actividad en vez de sobre la fase.
- `LoginViewModelTests`: el test que fijaba el defecto pasa a fijar lo contrario; se añaden el
  que faltaba —tras un fallo, un segundo intento entra— y el del campo vacío; los dos de
  cancelación y el del camino feliz se adaptan a la actividad.
- Capacidad nueva `inicio-de-sesion`, con el requisito que lo convierte en norma.

No cambia `LoginView`, ni `LoginLogic`, ni `AuthService`, ni nada de AppFoundation.

## Capabilities

### New Capabilities

- `inicio-de-sesion`: entrar en la app con usuario y contraseña, y qué le queda al usuario en
  la mano cuando el intento no sale —rechazado, sin red o con un campo vacío—.

### Modified Capabilities

Ninguna. El requisito de cancelación de `plataforma` no cambia: ya habla de `performLoad` y de
`performActivity`, y Login lo sigue cumpliendo.

## Fuera de alcance

- **Qué se considera «credenciales inválidas».** `LoginLogic.mapError` traduce cualquier
  `.client` —cualquier 4xx— a `invalidCredentials`. Hoy DummyJSON responde `400` tanto a una
  contraseña mala como a un cuerpo sin campos (`{"message":"Username and password required"}`,
  medido el 2026-11-25), así que el mensaje puede culpar al usuario de algo que no tecleó mal.
  No fue la causa esta vez y estrecharlo es otra decisión.

  **Corrección (2026-11-25, al implementar; la frase de arriba se deja como se acordó).**
  «Cualquier 4xx» es falso. `APIError.category` (CoreNetworking 1.3.1) da categoría propia a
  401, 403, 404 y 429, y `.client` es el resto de los 4xx. `mapError` lleva a
  `invalidCredentials` las categorías `.unauthorized` (401) y `.client` (400, 409, 413, 422…);
  un 403, un 404 o un 429 caen en `default` y se presentan como «Algo salió mal». Lo medido
  sigue en pie: un `400` se lee como credenciales malas venga de una contraseña mala o de un
  cuerpo sin campos. El punto sigue fuera de alcance.
- **El modo offline acepta cualquier credencial.** Hacer que `OfflineFixtures` rechace las
  malas, para que un `XCUITest` recorra este camino, es un cambio en el andamiaje de tests de
  UI. Aquí el comportamiento se fija en `LoginViewModelTests` y se comprueba a mano en el
  simulador.
- **Otras pantallas.** No se ha medido si alguna otra pierde un formulario o un campo de
  entrada al fallar. Este cambio toca Login y no afirma nada de las demás.
- **AppFoundation.** Que su vista de error no ofrezca salida cuando el error no es
  reintentable es del kit; aquí no se toca ni se sube de versión.
- **Recortar espacios, validar formato o avisar de mayúsculas** en los campos.
- **Los doce ficheros de `.claude/` borrados en el árbol sin commitear.** No son de este
  cambio y no se stagean con él.

## Criterios de aceptación

- [ ] `LoginViewModel.swift` no llama a `performLoad`:
      `grep -cE "performLoad *[({]" Packages/Features/Sources/LoginFeature/LoginViewModel.swift`
      devuelve `0`.
- [ ] Hay un test en `LoginViewModelTests` que, tras un login rechazado con
      `LoginError.invalidCredentials`, exige a la vez: `hasError == false`, `isIdle`
      —la fase no se ha movido—, `isPerformingActivity == false`, `banner?.message` igual al `message` del `screenError`
      de ese error, `username` igual a lo tecleado, y la raíz del router en `.login`.
- [ ] Hay un test que, tras ese fallo y sin crear otro view model, lanza un segundo `.login`
      que la lógica acepta y exige la raíz del router en `.products`.
- [ ] Hay un test que exige lo mismo que el primero cuando la lógica falla con
      `LoginError.emptyUsername`: la validación local sale por el mismo camino que el rechazo
      del servidor.
- [ ] Los dos tests de cancelación siguen existiendo y fijan lo mismo que antes —no queda en
      error, no queda cargando, y un login superado no le quita el indicador al que lo
      superó— leyendo `isPerformingActivity` e `inFlightActivity`.
- [ ] `swift test --filter LoginViewModelTests` en `Packages/Features` termina en
      `Test run with … passed`, con su última línea pegada en `tasks.md`.
- [ ] En el simulador, con la app compilada del cambio y 6 + 10 caracteres de relleno: tras el
      `400` el formulario sigue visible con el usuario tecleado y se ve el banner; un segundo
      toque en «Iniciar sesión» lanza una segunda petición **en el mismo proceso** (dos líneas
      `sent request` con el mismo PID en el log de CFNetwork). Captura y líneas del log,
      anotadas en `tasks.md`.
- [ ] `/kit-verifica` en verde y `/kit-revisa` sin hallazgos que bloqueen.

**Límite, dicho antes de empezar:** los `XCUITests` cruzan el login en cada test
(`AppStarterUITestCase.submitLogin`) y solo corren en el CI, como declara `LIMITES` en
`kit.conf`. Que sigan pasando con el envío por `performActivity` no lo prueba la firma local:
lo prueba el job `App` sobre el commit, que va después del push y por tanto fuera de las
tareas marcables.

## Impact

- `Packages/Features/Sources/LoginFeature/LoginViewModel.swift` — el método `login()` y los
  comentarios que hablan de `performLoad`.
- `Packages/Features/Tests/LoginFeatureTests/LoginViewModelTests.swift` — cuatro tests
  adaptados y dos nuevos.
- `openspec/specs/inicio-de-sesion/spec.md` — capacidad nueva, al archivar.
- Para el usuario: un login que falla ya no cambia de pantalla. El aviso pasa de título y
  mensaje a pantalla completa a solo el mensaje en un banner sobre el formulario, y mientras
  la petición está en vuelo el indicador se pinta encima del formulario en vez de sustituirlo.
- Tras un login correcto la fase del view model ya no pasa por `.content`: se queda en
  `.idle`, que el contenedor pinta igual, y la raíz del router cambia a `.products` en ese
  mismo paso.
