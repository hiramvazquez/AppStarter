## Context

El motivo, las corridas y la medición de los tres toolchains están en `proposal.md`. Lo que
condiciona el cómo:

- El workflow tiene **cuatro** jobs, tres de ellos en `macos-15` con el mismo bloque de
  selección copiado tres veces (`.github/workflows/ci.yml:32-38`, `:70-77`, `:129-135`). El
  cuarto, `showcase`, corre en `ubuntu-latest` y no toca Xcode.
- `app` depende de `packages` (`needs: packages`), así que un rojo en los paquetes deja los
  jobs de la app sin ejecutarse. Es lo que ha ocultado el fallo de `CartSnapshotTests` durante
  doce corridas.
- El repositorio hermano `spm-pro` ya resolvió esto y su workflow es el precedente
  (`openspec/specs/ci-toolchain/spec.md` y `.github/workflows/ci.yml` de ese repo). Usa
  `maxim-lobanov/setup-xcode@v1`, tres versiones en el `env:` y un job
  `aviso-toolchain-desarrollo` en la imagen `xcode-27` con `continue-on-error: true`.
- La asimetría que separa a los dos repos: en `spm-pro` el aviso temprano vigila el toolchain
  **nuevo** porque el contrato publicado es el viejo. Aquí el viejo es además el **más
  estricto** —6.2.4 y 6.3.3 rechazan lo que 6.4 acepta—, así que el job bloqueante y el de
  aviso cubren riesgos distintos, no el mismo en dos versiones.

## Goals / Non-Goals

**Goals**

- Que la versión validada esté escrita en un sitio y no se mueva sola.
- Que los dos sentidos del desfase estén cubiertos: lo que 26.3 rechaza y 27 acepta (job
  bloqueante), y lo que 27 rechazaría y 26.3 acepta (job de aviso).
- Que el bloque de selección deje de estar copiado tres veces.

**Non-Goals**

- Arreglar tests. El único rojo que había detrás, `CartSnapshotTests`, lo cerró
  `los-snapshots-fijan-su-locale` (corregido el 2026-09-19: aquí decía que seguía esperando).
- Reproducir la matriz de tres versiones de `spm-pro`.

## Decisions

### D1. Una sola versión fijada, no la matriz de tres de `spm-pro`

`XCODE_SOPORTADO: "26.3"` en el `env:` del workflow, y los tres jobs de macOS la leen.

*Por qué:* `spm-pro` necesita tres (`XCODE_MINIMO`, `XCODE_TESTS_MINIMO`, `XCODE_ACTUAL`)
porque publica librerías: tiene que comprobar el suelo que promete a quien las consume, por
separado de la versión con la que corre sus suites. AppStarter no publica nada. El owner ha
fijado un único suelo el 2026-09-17 y coincide con la versión con la que ya se ejecuta todo,
así que un segundo valor no mediría nada distinto — solo duplicaría el tiempo de CI de un
workflow cuyo job `app` ya tarda unos 20 minutos.

*Alternativa descartada — `XCODE_MINIMO` 26.0.1 más `XCODE_ACTUAL` 26.3:* añadiría un job que
comprueba una compatibilidad que nadie consume. Y en `spm-pro` está medido (2026-09-16, runs
`35127837096` y `35134647002`) que las suites de sus paquetes no corren por debajo de 26.2;
AppStarter depende de esos paquetes, así que ese job probablemente ni arrancaría.

### D2. `maxim-lobanov/setup-xcode@v1`, no `xcode-select -s` con la ruta a pelo

*Por qué:* es lo que ya usa `spm-pro`, y mantener los dos repos hermanos con la misma forma
importa más que ahorrar una dependencia. Además falla con un mensaje que nombra la versión
pedida cuando la imagen no la trae, que es exactamente el día en que hay que enterarse.

*Alternativa descartada — `sudo xcode-select -s /Applications/Xcode_26.3.app`:* cumpliría el
requisito de ser explícita y sin dependencia nueva. Se descarta por la coherencia con
`spm-pro` y porque su fallo —un path que no existe— es más difícil de leer en el log.

*Coste asumido:* una action de terceros nueva en este repo. Se fija por major (`@v1`), igual
que en `spm-pro`.

### D3. El aviso temprano corre solo los dos paquetes, no el job de la app

El job `aviso-toolchain-desarrollo` hace `swift build --build-tests` y `swift test` sobre
`Packages/Platform` y `Packages/Features`. No hace `xcodebuild test` contra simulador.

*Por qué:* lo que el aviso tiene que detectar es una incompatibilidad de **compilación** con
Swift 6.4, que es la que produjo `d575e75`. Eso vive entero en los paquetes. Montar el
simulador y los XCUITests en una imagen en preview añadiría unos 20 minutos y una fuente de
inestabilidad a un job que, por diseño, no puede hacer fallar la corrida — es decir, ruido que
nadie va a mirar.

### D4. Capacidad nueva `ci-toolchain`, y el desfase dentro del requisito que ya existe

Dos deltas: una capacidad nueva `ci-toolchain` con lo que el CI debe hacer, y un `MODIFIED`
del requisito «El toolchain con el que se construye el proyecto está documentado» de
`plataforma` con el desfase.

*Por qué partirlo así:* `plataforma` describe la plataforma del **código** —dominio, errores,
aislamiento—, y el comportamiento del CI no es eso. Pero el desfase sí es exactamente lo que
ese requisito ya cubre a medias: hoy dice con qué toolchain se construye en local y cuál es el
síntoma de usar otro; le falta que el CI usa uno distinto y que verificar en local no prueba
compatibilidad con él. Meterlo en un requisito nuevo dejaría a quien lee el primero creyendo
que ya está cubierto, que es el mismo error que se cometió con los protocolos en `d575e75`.

*Sobre crear una capacidad nueva:* es la regla de la casa no crear ficheros por cada hallazgo,
y aquí no se está creando uno por el hallazgo sino por una capacidad que el repo nunca tuvo
especificada —el CI— y que el repositorio hermano ya tiene con ese mismo nombre.

### D5. El job bloqueante y el de aviso cubren sentidos opuestos, y el workflow lo dice

El comentario del job de aviso explica que **no** es «la misma comprobación en una versión más
nueva»: el job fijado protege de escribir código que solo 6.4 acepta, y el de aviso protege de
escribir código que solo 26.3 acepta.

*Por qué escribirlo:* sin esa frase, el primero que vea dos jobs con el mismo `swift test` en
dos versiones concluirá que uno sobra, y el que quitará es el que no bloquea.

## Risks / Trade-offs

- **[Fijar 26.3 la congela, y un día `macos-15` dejará de traerla]** → es deliberado: ese día
  el job falla en seco y nombrando la versión que falta, en vez de saltar sola a otra. El
  requisito pide que subirla sea una decisión escrita, y el `env:` lleva la fecha y el comando
  para rehacer la medición.
- **[La imagen `xcode-27` está en preview y puede cambiar o desaparecer]** → el job lleva
  `continue-on-error: true` precisamente por eso, y la condición para volverlo bloqueante
  queda escrita con su enlace de seguimiento (actions/runner-images#14404).
- **[El job fijado puede destapar más errores de 26.3 que hoy no se ven]** → la corrida del
  2026-09-16 murió al emitir el módulo `UploadsFeature`, así que de los módulos posteriores no
  había dato. El run `35284398983` ya deja `Features` y `Platform` en verde con el arreglo del
  DTO, lo que reduce mucho ese riesgo, pero si aparece alguno se anota y se decide por
  escrito; no se prueban anotaciones contra el CI.
- **[Que el job `app` salga rojo sobre este cambio]** → ya no hay un rojo previsto detrás:
  `main` está en verde desde el run `35389558928`. Un rojo en `app` es un hallazgo nuevo y se
  trata como dice la tarea 4.4. (Corregido el 2026-09-19: aquí se daba por hecho que
  `CartSnapshotTests` seguiría roto.)
- **[Dependencia nueva de una action de terceros]** → asumido en D2, fijada por major y ya en
  uso en el repositorio hermano.
