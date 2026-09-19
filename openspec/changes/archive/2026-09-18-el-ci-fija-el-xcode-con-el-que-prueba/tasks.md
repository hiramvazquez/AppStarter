## 1. La versión fijada

- [x] 1.1 Añadir al `env:` de `.github/workflows/ci.yml` la variable `XCODE_SOPORTADO: "26.3.0"`
      (corregido tras la ronda del revisor: decía `"26.3"`, que la action trata como rango),
      con el comentario contiguo que dice: la decisión del owner y su fecha (2026-09-17), el
      comando `gh api repos/actions/runner-images/contents/images/macos/macos-15-arm64-Readme.md`
      y la lista de versiones que `macos-15` ofrecía ese día (16.0 … 26.0.1, 26.1.1, 26.2,
      26.3; ninguna 27), y la instrucción de rehacer esa comprobación al subirla.
      Verificación: el bloque `env:` existe al nivel del workflow y el comentario nombra la
      fecha y el comando.
      **Hecho (2026-09-19):** `env:` al nivel del workflow con `XCODE_SOPORTADO: "26.3.0"` y el comentario con la decisión, la fecha, el comando y la lista. Recomprobado ese día con el mismo comando: `macos-15` sigue ofreciendo 16.0 … 16.4, 26.0.1, 26.1.1, 26.2 y 26.3, ninguna 27.
- [x] 1.2 Sustituir los tres bloques de selección (`ci.yml:32-38` en `packages`, `:70-77` en
      `app`, `:129-135` en `integration`) por un paso `uses: maxim-lobanov/setup-xcode@v1` con
      `xcode-version: ${{ env.XCODE_SOPORTADO }}`. Ninguno declara la versión a pelo.
      Verificación: `grep -nE 'sort -V|LATEST|xcode-select' .github/workflows/ci.yml` sale
      vacío, y `grep -c 'XCODE_SOPORTADO' ` da 4 (la declaración y los tres usos).
      **Hecho:** el `grep` del selector viejo sale vacío y `XCODE_SOPORTADO` aparece 4 veces. Cada job conserva sus pasos y en el mismo orden (comprobado parseando el YAML).
- [x] 1.3 Dejar en cada uno de los tres jobs un paso que imprima la versión efectiva
      (`xcodebuild -version` y `swift --version`), como ya hace `spm-pro`. Verificación: el
      log de la corrida de la tarea 4.4 muestra `26.3` en los tres.
      **Hecho:** un paso `Versiones` en cada uno de los tres jobs. Los tres imprimen `Xcode 26.3` en la 4.4.

## 2. El aviso temprano

- [x] 2.1 Añadir el job `aviso-toolchain-desarrollo` con `runs-on: xcode-27`,
      `continue-on-error: true` y una matriz por paquete (`Platform`, `Features`) que ejecute
      `swift build --build-tests` y `swift test`. Sin `xcodebuild` ni simulador (design D3).
      Verificación: el job aparece en la corrida de la tarea 4.4 y su resultado no cambia la
      conclusión de la corrida.
      **Hecho** con `timeout-minutes: 20`, como `packages`. En la 4.4 aparece con sus dos
      entradas de la matriz, las dos en verde con Xcode 27.0 / Swift 6.4.
- [x] 2.2 Escribir en el comentario del job las dos cosas que el requisito pide y que D5
      explica: la condición concreta para volverlo bloqueante —que la imagen `xcode-27` salga
      de preview— con el enlace actions/runner-images#14404, y que este job cubre el sentido
      **contrario** al job fijado, para que nadie concluya que uno de los dos sobra.
      Verificación: el comentario contiene ambas frases y el enlace.
      **Hecho:** el comentario lleva la condición con el enlace y la frase del sentido contrario.

## 3. El desfase, escrito

- [x] 3.1 Ampliar la sección de toolchain de `AGENTS.md` (hoy en `AGENTS.md:29-44`) con: que
      el CI valida con Xcode 26.3 / Swift 6.2.4, que en local se desarrolla con Xcode 27 /
      Swift 6.4, y que una verificación local en verde —`/kit-verifica` incluido— no prueba
      compatibilidad con la del CI, con el diagnóstico `[#IsolatedConformances]` como el caso
      medido que lo demuestra. Verificación: la sección nombra `26.3` y advierte del límite.
      **Hecho:** párrafo nuevo tras el bloque de swiftly; nombra `26.3` y dice que la verificación local no prueba la del CI.
- [x] 3.2 No crear ningún fichero nuevo de documentación para esto: la sección existente es el
      sitio. Verificación: `git status --short` tras la tarea 3.1 no lista ningún `.md` nuevo
      fuera de `openspec/changes/`.
      **Hecho:** ningún `.md` nuevo.
- [x] 3.3 *Añadida al implementar, el 2026-09-19:* la sección de CI de `README.md` dice que el
      Xcode se elige «el más reciente disponible en el runner […] nunca fijado a una versión
      concreta», que este cambio vuelve falso, y no lista el job de aviso. El acuerdo no la
      contaba. Se corrige ahí mismo: la versión fijada, dónde vive, y el job de aviso en la
      lista. Verificación: `grep -n 'más reciente\|nunca fijado' README.md` sale vacío y la
      lista de jobs nombra `aviso-toolchain-desarrollo`.
      **Hecho:** el `grep` sale vacío y la lista nombra el job de aviso.

## 4. Cierre

- [x] 4.1 `openspec validate el-ci-fija-el-xcode-con-el-que-prueba --strict` en verde.
      Verificación: la salida del comando, anotada.
      **Hecho** al cerrar la propuesta: `Change 'el-ci-fija-el-xcode-con-el-que-prueba' is
      valid`. (La orden lleva el nombre como argumento posicional: `--change` no existe en
      este CLI y el primer intento falló con `unknown option '--change'`.)
- [x] 4.2 `/kit-revisa` sobre el diff: ¿esto rompe algo? Es el paso obligatorio de `AGENTS.md`
      antes de commitear. Verificación: el veredicto, anotado. Atención especial a que los
      tres jobs sigan haciendo lo mismo que hacían aparte de la selección del toolchain — el
      riesgo real de esta edición es cargarse un paso al sustituir el bloque.
      **Ronda 1 del revisor (2026-09-19): AMBER · comportamiento: sí.** Los tres jobs conservan
      todos sus pasos, `env:`, `needs:`, `if:` y `working-directory` (comparado contra `HEAD`).
      Dos hallazgos, los dos contradicciones con el propio acuerdo: `"26.3"` es un rango para
      `setup-xcode` y aceptaría un 26.3.x posterior sin avisar (→ `"26.3.0"`, criterio
      renegociado por escrito); y la spec pedía que todo job de macOS leyera la versión, cosa
      que el job de aviso no puede (→ la regla es de los jobs bloqueantes). Como el primero
      cambia el workflow, segunda mirada del mismo revisor sobre el arreglo: **GREEN**
      (`26.3.0` es lo que `setup-xcode` lee de la imagen: el log de `spm-pro` dice «Xcode is
      set to 26.3.0 (17C529)»; con solo un 26.3.1 no encontraría nada y fallaría).
- [x] 4.3 `/kit-verifica` en verde. Verificación: la firma, anotada.
      **Límite, escrito por adelantado**: esta firma corre con Xcode 27 y por tanto **no
      puede** ver la clase de error que motiva el cambio (`proposal.md`, punto 3 de la
      medición), y además este cambio no toca código Swift. Lo único que demuestra es que
      nada se ha roto de camino. La prueba del cambio es la 4.4.
      **Hecho (2026-09-19), con el kit 2.2.0:** verde en 64 s, los ocho pasos de `kit.conf` y
      sin lógica repetida en lo que toca el cambio. Firma `diff: e12eba12…`, `toolchain: Swift
      6.4 · Xcode 27.0`, `resultado: verde`. Anotarla aquí no la invalida: desde la 2.2.0,
      `openspec/` queda fuera de la huella.
- [x] 4.4 **La prueba de verdad**: la corrida del CI sobre este cambio. Verificación: el
      número de run, anotado, junto con la versión que imprimen los tres jobs de macOS (debe
      ser `26.3` en los tres) y la conclusión del job de aviso.
      Va después de `/kit-verifica` por necesidad —el CI solo corre sobre lo ya empujado—, no
      porque importe menos.
      **Ya no hay un rojo previsto** (corregido el 2026-09-19: aquí se daba por previsto el
      de `CartSnapshotTests`, que cerró `los-snapshots-fijan-su-locale`). El job `app` está en
      verde en `main` desde el run `35389558928`; si sale rojo sobre este cambio, se anota el
      run y el test y se decide por escrito si entra aquí.
      **Lo que sí cuenta**: que algún job de macOS no imprima `26.3`, que el job de aviso
      haga fallar la corrida, o que aparezca un error de compilación en 26.3 en un módulo que
      hoy está verde. En ese último caso se anota el fichero y el diagnóstico y se decide por
      escrito si entra aquí; no se prueban anotaciones contra el CI.
      **Hecho (2026-09-19): dos corridas sobre `6c4d3cc`, las dos `success`.** Hacen falta dos
      porque `integration` solo corre con `workflow_dispatch`.
      - Run `35422327712` (push): `packages` (Platform y Features) y `app` imprimen
        `Xcode 26.3` · `Build version 17C529` · `Apple Swift version 6.2.4`, y `setup-xcode`
        dice «Xcode is set to 26.3.0 (17C529)». `integration`, *skipped*.
      - Run `35423039462` (dispatch): `integration` imprime lo mismo y pasa sus 2 tests contra
        DummyJSON. Los demás jobs repiten `26.3` y verde.
      - Aviso temprano, en las dos: `success` en Platform y en Features, con `Xcode 27.0`
        (`27A266a`) y `Swift 6.4`. Con Xcode 27 salen los mismos tests que con 26.3
        (Platform 14 en 5 suites, Features 217 en 39): `swift test` los reparte en una
        ejecución por target y hay que sumar.
      - Ningún error de compilación nuevo en 26.3: los paquetes pasan sus tests, lint y
        archlint, y `app` termina en `** TEST SUCCEEDED **`.
      Lo que estas corridas **no** prueban: con el aviso en verde no se ve que
      `continue-on-error` impida que un rojo suyo tumbe la corrida. Esa garantía es la de la
      documentación de GitHub Actions y la lectura del YAML.
