## Why

CoreNetworking `1.3.2` salió el 2026-11-26 y corrige un fallo que afecta a cualquier app que
la consuma: un `Retry-After` como `inf` o `1e30` en una respuesta terminaba el proceso
(`Fatal error` al convertir a entero), y uno finito enorme (`86400`) dejaba la petición
esperando horas. AppStarter declara `1.3.1`, que trae los dos defectos: lo que hoy decide si
la app se cae es lo que mande el servidor en esa cabecera.

## What Changes

- **Sube el suelo de CoreNetworking de `1.3.1` a `1.3.2`** en los tres sitios donde vive:
  `project.yml`, `Packages/Platform/Package.swift` y `Packages/Features/Package.swift`.
- **Los `Package.resolved` pasan a resolver `corenetworking 1.3.2`**: los dos versionados
  (`Packages/Platform/Package.resolved` y `Packages/Features/Package.resolved`) y el del
  workspace de `AppStarter.xcodeproj`, que xcodegen regenera y git no ve.
- **AppFoundation se queda en `1.4.2`**: no hay versión nueva.

No se toca ninguna fuente Swift: los dos `Package.swift` que cambian son manifiestos. En el
diff de git son cinco ficheros, los tres manifiestos y los dos `Package.resolved`.

**No es una migración.** Medido el 2026-11-26 en spm-pro, con
`git diff cn-1.3.1 cn-1.3.2 -- Sources`: las líneas de código que cambian están todas
dentro del cuerpo de `APIError.parseRetryAfter` y de `APIService.performWithRetry`; ninguna
declaración pública se añade, se quita ni cambia de firma. CoreNetworking no envía plugins,
así que tampoco hay reglas nuevas que corran sobre nuestras fuentes.

**Sí cambia comportamiento**, y conviene que quede escrito qué parte le llega a esta app:

- Un `Retry-After` que no sea segundos en dígitos o una HTTP-date se ignora y se usa el
  backoff (antes `2.5`, `+5`, `-5` y `nan` se aceptaban).
- Un `Retry-After` mayor que `RetryPolicy.maxDelay` ya no se espera: no se reintenta y el
  error vuelve a quien llamó. Le llega a todo `APIService` de este repo construido sin
  `RetryPolicy` propia, que se queda con la por defecto (techo de 16 s): un 408, 429 o 5xx
  con un `Retry-After` de más de 16 s devuelve el error en el acto en vez de esperar y
  repetir. Y le llega también al `.retry` de `TokenRefreshRetrier`, que este proyecto cablea
  en `Packages/Platform/Sources/Networking/NetworkingWiring.swift`: si un 401 trajera un
  `Retry-After` de más de 16 s, el token se renovaría pero la petición no se repetiría.

Medido el 2026-11-26 con
`grep -rn -e RetryPolicy -e maxDelay -e retryAfter -e Retry-After -e RetryDecision -e RequestRetrier -e TokenRefreshRetrier`
sobre `Packages/Platform/{Sources,Tests}`, `Packages/Features/{Sources,Tests}`, `App`,
`AppTests`, `AppUITests` y `AppSnapshotTests`: además del cableado anterior, la única
`RetryPolicy` propia es la del laboratorio de `DiagnosticsService`
(`maxDelay: .milliseconds(200)`), y su fixture responde `503, 503, 200` sin `Retry-After`,
así que va por el backoff, que no cambia. Ningún test ni fuente del repo lee ni fija esa
cabecera.

## Capabilities

### New Capabilities

Ninguna.

### Modified Capabilities

- `plataforma`: el requisito «Versión mínima de los kits» sube CoreNetworking a `1.3.2` y
  añade el motivo: por debajo, una cabecera del servidor puede terminar el proceso. Los
  motivos vigentes de AppFoundation no cambian.

## Fuera de alcance

- **Subir AppFoundation.** Sigue en `1.4.2`; no hay versión nueva.
- **Cambiar la `RetryPolicy` de la app o la del laboratorio de Diagnostics.** La de la app
  sigue siendo la por defecto, con su techo de 16 s. Decidir si esta app quiere esperar más
  por un `Retry-After` es otra decisión, y no la necesita esta subida.
- **Un experimento de `Retry-After` en el laboratorio de Diagnostics.** Enseñaría el
  comportamiento nuevo, pero es una feature, no una subida.
- **Regrabar snapshots**, tocar CI, XCUITests o el mínimo de iOS: la subida no los mueve.
- Añadir features o refactorizar lo que ya funciona.

## Criterios de aceptación

- [ ] `project.yml`, `Packages/Platform/Package.swift` y `Packages/Features/Package.swift`
      declaran CoreNetworking `from: 1.3.2` y siguen declarando AppFoundation `from: 1.4.2`.
- [ ] `Packages/Platform/Package.resolved` y `Packages/Features/Package.resolved` fijan
      `corenetworking 1.3.2` y `appfoundation 1.4.2`.
- [ ] `git diff --stat` no lista nada fuera de los tres manifiestos, los dos
      `Package.resolved` y `openspec/`.
- [ ] `swift build --build-tests` y `swift test` pasan en `Packages/Platform` y en
      `Packages/Features`, con la última línea de cada uno pegada en `tasks.md`.
- [ ] `xcodebuild test -only-testing:AppTests -only-testing:AppSnapshotTests` sobre
      `iPhone 17 Pro` termina en `** TEST SUCCEEDED **`, y `AppSnapshotTests/__Snapshots__/`
      no cambia.
- [ ] `/kit-verifica` en verde y `/kit-revisa` sin hallazgos que bloqueen.
- [ ] El CI del commit, que corre con Xcode 26.3, sale en verde.

## Impact

- **Dependencias**: CoreNetworking `1.3.1` → `1.3.2`, publicada y resoluble (tag `1.3.2` en
  `hiramvazquez/CoreNetworking`, commit `ce8be46`). AppFoundation sin cambios.
- **Código**: ninguno.
- **Manifiestos y lockfiles**: cinco ficheros en git, más el `Package.resolved` del
  workspace, que no está versionado.
- **Riesgo**: bajo. Lo que la subida cambia en tiempo de ejecución solo se nota si el servidor
  manda `Retry-After`: con uno de más de 16 s, cualquier petición que use la `RetryPolicy`
  por defecto devuelve el error en vez de esperar, y el refresco de token ante un 401 así
  renueva el token sin repetir la petición. La medición de arriba no encuentra en el repo
  ninguna fuente, test ni fixture que dependa de esa cabecera.

*(Corregido el 2026-11-26 tras `/kit-revisa`, ronda 1: la redacción original decía que el
techo de `maxDelay` «solo alcanza al refresco de token». Se dejaba fuera la `RetryPolicy` por
defecto de los `APIService` del repo, que es por donde le llega de verdad: un 408, 429 o 5xx
con un `Retry-After` de más de 16 s. No cambia lo entregado; solo el texto.)*
