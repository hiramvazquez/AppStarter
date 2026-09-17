# El DTO de Uploads deja de viajar con una conformidad aislada

## Why

**El CI de `main` no tiene una corrida verde desde al menos el 2026-09-09**: doce corridas
seguidas en rojo, todas con el job `Features (swift test + archlint)` caído. El rojo ha
tenido dos causas distintas, y conviene no confundirlas:

- hasta el 2026-09-15, violaciones `todo` de SwiftLint en `ProductsViewModel.swift` y sus
  tests («Todo Violation: TODOs should be resolved»), que `94deb9c` quitó al pasar el lint a
  estricto. En el run de hoy no queda ninguna: `grep -c "Todo Violation"` da 0;
- desde el 2026-09-15 por la tarde, el diagnóstico de este cambio, que llegó con `d575e75`
  esa misma tarde.

Medido hoy en el run `35268191849`, y antes en el `35042313299`: el job
`Features (swift test + archlint)` muere con

```
Packages/Features/Sources/UploadsFeature/Services/UploadsService.swift:66:38: error:
main actor-isolated conformance of 'UploadPayload' to 'Encodable' cannot be used in
caller isolation inheriting-isolated context [#IsolatedConformances]
```

El CI usa **Xcode 26.3.0 / Swift 6.2.4** —lo imprime su propio paso, que elige el Xcode más
nuevo del runner—. Esta máquina va con Xcode 27 / Swift 6.4, donde ese fichero compila sin
una queja: `swift build` en `Packages/Features` y `/kit-verifica` entero han estado en verde
todo el día. Por eso el rojo lleva dos días sin que nadie lo vea desde local.

**La causa, medida y no deducida.** `d575e75` («el proyecto vuelve a compilar con Xcode 27 y
Swift 6.4», 2026-09-15) anotó `public nonisolated protocol UploadsServicing`. Con eso,
`addProduct` pasó a heredar el aislamiento de quien la llama. Y `UploadPayload`
(`UploadsService.swift:32`) es un `private struct` de nivel de fichero **sin** `nonisolated`,
así que con `defaultIsolation(MainActor)` y `InferIsolatedConformances`
(`Packages/Features/Package.swift:9-11`) su conformidad a `Encodable` queda aislada al
MainActor. Usarla desde un contexto que hereda el aislamiento del llamante es error en 6.2.4
y no lo es en 6.4. El commit anotó el contrato y se dejó el DTO que ese contrato serializa.

**Es un caso aislado, no una deuda general.** `UploadPayload` es el único DTO de nivel de
fichero del repo que no llevaba la anotación: los otros dos (`AppSettings`, `StoredSession`)
ya son `nonisolated`, y los 18 que quedan están anidados dentro del tipo de su petición.

> *Enmendado el 2026-09-17, tras la revisión.* Esto se apoyaba en que «6.2.4 los compiló
> todos sin queja en esa misma corrida», y **era falso**: en el run `35268191849` el build
> murió antes de llegar a ellos —compiló ocho módulos, y 13 de los 18 anidados viven en los
> que no llegó a compilar—. El respaldo bueno es la sonda local del apartado de criterios,
> que sí los cubre todos. Y el mecanismo también estaba mal contado: lo que exime a esos 18
> no es el anidamiento, sino estar dentro de un conformante de `BaseRequest`, que es
> `Sendable` y viene de un módulo sin `defaultIsolation`. Medido: un tipo anidado en otro
> sin anotar falla igual, aunque el exterior sea `Sendable`.

## What Changes

- **`UploadPayload` pasa a `private nonisolated struct`.** Una palabra, en
  `UploadsService.swift:32`. Es lo que el tipo es: dos `String` que se serializan fuera del
  MainActor, ya declarado `Sendable`.
- **La regla queda escrita** en el requisito de aislamiento que ya existe, que hoy solo habla
  de protocolos con conformante `actor`. Sin eso, el siguiente DTO de nivel de fichero repite
  el fallo y lo descubre el CI dos días después.

Sin cambio de comportamiento y sin cambio de API: el tipo es `private`.

## Capabilities

### Modified Capabilities

- `plataforma`: el requisito «Un contrato que implementa un actor se declara nonisolated»
  gana la mitad que le falta —los tipos cuya conformidad se infiere aislada— y un escenario.

## Fuera de alcance

- **Fijar el toolchain del CI.** Hoy el workflow coge el Xcode más nuevo del runner
  (`.github/workflows/ci.yml:34`), así que ni prueba una versión concreta ni declara un
  mínimo, y un cambio de imagen puede romper o arreglar el repo sin que nadie toque código.
  Eso es una decisión del owner —qué versión soporta AppStarter— y va en otro cambio, con el
  precedente de `spm-pro` (`openspec/specs/ci-toolchain/spec.md` de ese repo) encima de la
  mesa.
- **Lo demás de `d575e75`**: los siete protocolos anotados, `DeviceCameraCapture` y la deuda
  escrita del render UIKit.
- **Cualquier otro rojo que el CI destape detrás de este.** Los jobs `Platform`,
  `Integration` y `App` se quedaron cancelados o saltados por el fail-fast de la matriz, así
  que de ellos no hay dato de hoy. `Integration` y `App` llevan **doce corridas sin
  ejecutarse**, desde antes del 2026-09-09: que este arreglo los desbloquee no significa que
  estén verdes, significa que por fin se van a medir. Si alguno sale en rojo, es un hallazgo
  nuevo y se trata aparte — este cambio no se hace responsable de ellos, y tampoco se declara
  «el CI arreglado» hasta que alguien los mire.

## Criterios de aceptación

- [ ] `UploadsService.swift:32` declara `private nonisolated struct UploadPayload`, y el
      `git diff` del fichero no toca ninguna otra línea.
- [ ] Ningún otro DTO de nivel de fichero de `Packages/*/Sources` ni de `App/` se queda sin
      `nonisolated`. Si aparece alguno, se anota con su fichero y se decide: o entra en este
      cambio o se dice por qué no.
      *Corregido el 2026-09-17:* este criterio traía un `grep` con escapes de BRE que en esta
      máquina no ejecuta («ugrep: error: empty (sub)expression»). Se comprueba con
      `grep -rnE '^[a-z ]*(struct|enum|class|actor) .*(Encodable|Decodable|Codable)'` y,
      sobre todo, con la sonda del último criterio, que es la que lo mide con el compilador.
- [ ] El requisito de aislamiento de `plataforma` dice la regla para los tipos, con el
      diagnóstico literal que produce incumplirla.
- [ ] `/kit-verifica` en verde (Xcode 27), y `/kit-revisa` sin hallazgos que bloqueen.
- [ ] **El job `Features (swift test + archlint)` del CI en verde**, y `Platform` deja de
      cancelarse por el fail-fast. El número de run queda escrito en `tasks.md`.

      **Límite, enmendado el 2026-09-17 tras la revisión**: este acuerdo decía «esto no se
      puede comprobar en local», y el límite es más pequeño. Sigue siendo cierto que el
      toolchain del CI no compila aquí —un Swift de swift.org más antiguo que el de Xcode falla
      con `unknown argument: '-target-arch-variant'` contra el SDK de macOS 27, el mismo
      síntoma que ya recoge el requisito «El toolchain con el que se construye el proyecto está
      documentado»—, así que la prueba final la sigue dando el CI. Pero el diagnóstico **sí se
      reproduce aquí**, apagando la feature que hace heredar el aislamiento:

      ```bash
      swift build --target UploadsFeature \
          -Xswiftc -disable-upcoming-feature -Xswiftc NonisolatedNonsendingByDefault
      ```

      Con eso, un `async` sin anotar deja de heredar el aislamiento del llamante y pasa a
      `nonisolated` completo, que es un chequeo **más estricto** que el del CI. Medido en los
      dos sentidos: sin la palabra da `error` en `UploadsService.swift:66:38` —mismo fichero,
      línea y columna que el CI, solo cambia la coletilla del contexto—; con la palabra,
      `Build complete`.

      Lo que esta sonda NO puede ver es una diferencia de **inferencia** entre 6.2.4 y 6.4; la
      de **uso**, que es la que produjo este rojo, sí. Y sobre el paquete entero saca dos
      errores ajenos y preexistentes (`SettingsLogic.swift`, `CartLogic.swift`: `sending 'self'
      risks causing data races`), así que se acota al target.

## Impact

| Fichero | Qué cambia |
|---|---|
| `Packages/Features/Sources/UploadsFeature/Services/UploadsService.swift` | una palabra en la línea 32 |
| `openspec/specs/plataforma/spec.md` (al archivar) | el requisito de aislamiento |

Ningún efecto sobre la app en ejecución: el aislamiento de una conformidad no existe en
tiempo de ejecución, y el tipo ya era `Sendable`.
