## 1. La versión fijada

- [ ] 1.1 Añadir al `env:` de `.github/workflows/ci.yml` la variable `XCODE_SOPORTADO: "26.3"`,
      con el comentario contiguo que dice: la decisión del owner y su fecha (2026-09-17), el
      comando `gh api repos/actions/runner-images/contents/images/macos/macos-15-arm64-Readme.md`
      y la lista de versiones que `macos-15` ofrecía ese día (16.0 … 26.0.1, 26.1.1, 26.2,
      26.3; ninguna 27), y la instrucción de rehacer esa comprobación al subirla.
      Verificación: el bloque `env:` existe al nivel del workflow y el comentario nombra la
      fecha y el comando.
- [ ] 1.2 Sustituir los tres bloques de selección (`ci.yml:32-38` en `packages`, `:70-77` en
      `app`, `:129-135` en `integration`) por un paso `uses: maxim-lobanov/setup-xcode@v1` con
      `xcode-version: ${{ env.XCODE_SOPORTADO }}`. Ninguno declara la versión a pelo.
      Verificación: `grep -nE 'sort -V|LATEST|xcode-select' .github/workflows/ci.yml` sale
      vacío, y `grep -c 'XCODE_SOPORTADO' ` da 4 (la declaración y los tres usos).
- [ ] 1.3 Dejar en cada uno de los tres jobs un paso que imprima la versión efectiva
      (`xcodebuild -version` y `swift --version`), como ya hace `spm-pro`. Verificación: el
      log de la corrida de la tarea 4.4 muestra `26.3` en los tres.

## 2. El aviso temprano

- [ ] 2.1 Añadir el job `aviso-toolchain-desarrollo` con `runs-on: xcode-27`,
      `continue-on-error: true` y una matriz por paquete (`Platform`, `Features`) que ejecute
      `swift build --build-tests` y `swift test`. Sin `xcodebuild` ni simulador (design D3).
      Verificación: el job aparece en la corrida de la tarea 4.4 y su resultado no cambia la
      conclusión de la corrida.
- [ ] 2.2 Escribir en el comentario del job las dos cosas que el requisito pide y que D5
      explica: la condición concreta para volverlo bloqueante —que la imagen `xcode-27` salga
      de preview— con el enlace actions/runner-images#14404, y que este job cubre el sentido
      **contrario** al job fijado, para que nadie concluya que uno de los dos sobra.
      Verificación: el comentario contiene ambas frases y el enlace.

## 3. El desfase, escrito

- [ ] 3.1 Ampliar la sección de toolchain de `AGENTS.md` (hoy en `AGENTS.md:29-44`) con: que
      el CI valida con Xcode 26.3 / Swift 6.2.4, que en local se desarrolla con Xcode 27 /
      Swift 6.4, y que una verificación local en verde —`/kit-verifica` incluido— no prueba
      compatibilidad con la del CI, con el diagnóstico `[#IsolatedConformances]` como el caso
      medido que lo demuestra. Verificación: la sección nombra `26.3` y advierte del límite.
- [ ] 3.2 No crear ningún fichero nuevo de documentación para esto: la sección existente es el
      sitio. Verificación: `git status --short` tras la tarea 3.1 no lista ningún `.md` nuevo
      fuera de `openspec/changes/`.

## 4. Cierre

- [x] 4.1 `openspec validate el-ci-fija-el-xcode-con-el-que-prueba --strict` en verde.
      Verificación: la salida del comando, anotada.
      **Hecho** al cerrar la propuesta: `Change 'el-ci-fija-el-xcode-con-el-que-prueba' is
      valid`. (La orden lleva el nombre como argumento posicional: `--change` no existe en
      este CLI y el primer intento falló con `unknown option '--change'`.)
- [ ] 4.2 `/kit-revisa` sobre el diff: ¿esto rompe algo? Es el paso obligatorio de `AGENTS.md`
      antes de commitear. Verificación: el veredicto, anotado. Atención especial a que los
      tres jobs sigan haciendo lo mismo que hacían aparte de la selección del toolchain — el
      riesgo real de esta edición es cargarse un paso al sustituir el bloque.
- [ ] 4.3 `/kit-verifica` en verde. Verificación: la firma, anotada.
      **Límite, escrito por adelantado**: esta firma corre con Xcode 27 y por tanto **no
      puede** ver la clase de error que motiva el cambio (`proposal.md`, punto 3 de la
      medición), y además este cambio no toca código Swift. Lo único que demuestra es que
      nada se ha roto de camino. La prueba del cambio es la 4.4.
- [ ] 4.4 **La prueba de verdad**: la corrida del CI sobre este cambio. Verificación: el
      número de run, anotado, junto con la versión que imprimen los tres jobs de macOS (debe
      ser `26.3` en los tres) y la conclusión del job de aviso.
      Va después de `/kit-verifica` por necesidad —el CI solo corre sobre lo ya empujado—, no
      porque importe menos.
      **Lo que NO cuenta como fallo de este cambio**: que el job `app` salga rojo por
      `CartSnapshotTests`. Está previsto en «Fuera de alcance» y es lo que el CI destapa al
      desbloquearse. Si sale, se anota aquí el run y se abre el cambio aparte; no se toca
      nada de este.
      **Lo que sí cuenta**: que algún job de macOS no imprima `26.3`, que el job de aviso
      haga fallar la corrida, o que aparezca un error de compilación en 26.3 en un módulo que
      hoy está verde. En ese último caso se anota el fichero y el diagnóstico y se decide por
      escrito si entra aquí; no se prueban anotaciones contra el CI.
