## Context

El motivo, las cifras, la decisión del owner sobre `.swiftlint.yml` y la renegociación de la subida
de versión están en `proposal.md`. Lo que condiciona el cómo:

- `verifica.sh` (ios-agent-kit) hace `cd` a la raíz del repo y ejecuta cada `paso "<nombre>" <orden…>`
  tal cual. Si la orden sale con código distinto de 0, el informe enseña sus 15 últimas líneas. Un
  paso en rojo no para los siguientes.
- `swift format lint --strict` sale con código distinto de 0 si encuentra cualquier aviso. En local,
  `swift` es el de swiftly y coincide con el de Xcode (Swift 6.4, medido el 2026-09-17). CI usa el
  Xcode más nuevo del runner `macos-15`.
- `features-pasa-swift-format-estricto` (2026-09-15) midió swift-format 6.2.4, que es la versión
  de CI, contra la 6.3.x local. Sobre `Packages/Features`, las dos dieron los mismos avisos y el
  mismo formato. No se ha vuelto a medir con la 6.4 sobre este repo.
- AppFoundation pasa de `1.4.1` a `1.4.2`, la versión que resolverá el repo tras este cambio. En su
  `Plugins/GenerateFeature/MultiMode.swift`:
  - `registerAppModule` sigue la puntuación que ya tiene la lista de módulos: si el último elemento
    no lleva coma, se la pone y deja el nuevo sin ella. En la 1.4.1 insertaba `"\(expression),"`
    sin tocar la línea anterior y el build fallaba;
  - el motor de plantillas elimina las líneas de etiqueta de bloque y ordena los imports, así que
    lo generado pasa `swift format lint --strict` sin retocar. En la 1.4.1 no;
  - `registerAppRoute` sigue buscando `App/AppRoute.swift`, que aquí no existe, e imprime que el
    `case` se añada a mano con esa ruta.
- En `App/AppModule.swift`, `makeModules()` devuelve un array literal cuyo último elemento no lleva
  coma, igual que pide `.swift-format` (`multiElementCollectionTrailingCommas: false`).
- El `.xcodeproj` no se versiona: lo regenera `Scripts/bootstrap.sh` (`xcodegen generate`) a partir
  de `project.yml`.

## Goals / Non-Goals

**Goals:**

- Que la firma de `/kit-verifica` falle con cualquier fichero que la orden de swift-format de CI
  rechazaría, venga del generador o escrito a mano.
- Que quien siga la guía de `AGENTS.md` después de `generate-feature` acabe con una app que compila y
  un árbol que pasa la verificación, sin ir a descubrir los pasos por el error.
- Que la guía describa la versión de AppFoundation que el repo resuelve.

**Non-Goals:**

- Que la guía cubra `--service-from`/`--store-from`: `README.md` ya documenta su fricción propia, y
  los pasos de este cambio no dependen de esas opciones.

## Decisions

### La subida a 1.4.2 va en este cambio, no en otro

La guía de `AGENTS.md` lista los pasos que el generador deja a mano, y esos pasos dependen de la
versión. Con la 1.4.1 eran cuatro; con la 1.4.2 son dos (ver `proposal.md`).

*Por qué:* la guía se valida siguiéndola al pie de la letra. Validarla contra la 1.4.1 y subir
después obligaría a dar por buena una guía de cuatro pasos con defectos conocidos y a reescribirla
en el cambio siguiente: dos validaciones para llegar al mismo sitio, y la primera sobre algo que ya
se sabía que iba a caducar.

*Alternativa descartada:* la que decía este mismo acuerdo antes de renegociarse, «si una versión
posterior arregla la coma o el formato, sus pasos se quitan de la guía en otro cambio». Tenía sentido
cuando la 1.4.2 no existía.

### swift-format entra como dos pasos, uno por paquete

`paso "Platform · swift-format"` y `paso "Features · swift-format"`, cada uno con
`bash -c 'cd Packages/<paquete> && swift format lint --strict --configuration ../../.swift-format --recursive Sources Tests'`.
Van justo después de `SwiftLint · --strict`.

*Por qué:* es la orden de CI carácter a carácter, así que comparar las dos es leer dos líneas. Y
repite la forma que ya tienen los builds y los tests: un paso por paquete. Si fallan los dos
paquetes, cada uno enseña su propia cola en el informe. Van delante de los builds por la misma razón
que SwiftLint: cuestan menos de un segundo y encabezan el informe.

Que la 1.4.2 genere código limpio no hace sobrar el paso: la verificación no puede depender de que
cada fichero lo escriba el generador.

*Alternativas:*

- Un solo paso con un bucle sobre los dos paquetes. Con `set -e`, un Platform en rojo ocultaría
  Features. Sin él, hay que acumular el código de salida a mano, y el informe mezcla las colas de
  los dos.
- Lanzarlo desde la raíz con `--recursive Packages/*/Sources Packages/*/Tests`. Ya no es la orden de
  CI, y no se ve a simple vista que cubran lo mismo.

### Mismo alcance que CI, no todo el repo

A diferencia de SwiftLint, que en `kit.conf` lintea todo el repo por decisión del owner del
2026-09-15. Fuera del alcance de CI hoy hay avisos (ver `proposal.md`, «Fuera de alcance»):
ampliarlo obliga a formatear `App/` y los manifiestos, y eso es otro cambio. El comentario del paso
en `kit.conf` dice que el alcance es el de CI a propósito, y sin cifras: una cifra escrita ahí
caduca.

### La guía ya no pide poner la coma ni formatear

Con la 1.4.1 hacían falta dos pasos más: poner la coma que faltaba en la lista de módulos de
`App/AppModule.swift` y pasar `swift format format --in-place` sobre los directorios de la feature.
Con la 1.4.2 los dos son trabajo del generador, y está medido que lo hace (ver `proposal.md`).

*Por qué no dejarlos «por si acaso»:* un paso que no hace nada enseña a saltarse los pasos. Y si una
versión futura volviera a romper el formato, los pasos de swift-format de `kit.conf` lo cazarían en
la firma.

### La guía dice con qué versión del generador se comprobó

La sección nombra AppFoundation 1.4.2. *Por qué:* el paso del `case` existe por un defecto del
generador, que busca `AppRoute` donde este repo no lo tiene. Quien suba de versión tiene que saber
que ese paso puede sobrar. Es una versión, no un recuento, así que no caduca en silencio: deja de
coincidir con `Package.resolved`.

### La guía se valida siguiéndola, en un worktree desechable

Se genera una feature `--api --local` y se aplican los dos pasos tal como están escritos, sin
formatear nada a mano. Después se ejecutan SwiftLint, las dos órdenes de swift-format, `swift build`
de Features y el `build-for-testing` de la app.

*Por qué `--api --local`:* es la variante que más ficheros genera. Y los dos pasos no dependen de la
variante: tocan `Domain` y el proyecto de Xcode. Las cuatro variantes ya las ensayó el owner el
2026-09-17.

*Por qué `GuiaPrueba` como nombre:* `Networking` ya declara un `CatalogError` público, y una feature
`Catalog` generaría otro `CatalogError` en su propio módulo. Compilaría, pero cualquier fichero que
importe los dos módulos tendría un nombre ambiguo, y la validación no debe poder fallar por el
nombre elegido.

*Por qué un worktree en el scratchpad y no este:* la feature de prueba no puede acabar en el diff.
Al worktree nuevo se le aplican los cambios sin commitear de este (`git diff | git apply`), para que
valide la guía, la configuración y la versión nuevas y no las de `HEAD`.

## Risks / Trade-offs

- **[swift-format local distinto del de CI]** → Una versión puede dar avisos que la otra no dé, y la
  firma quedaría en verde con CI en rojo, o al revés. Se midió igual entre la 6.2.4 y la 6.3.x
  (2026-09-15), pero no con la 6.4 sobre este repo. Queda como límite declarado, igual que en
  SwiftLint, cuya versión tampoco se fija.
- **[`swift` del PATH no es el de Xcode]** → El paso falla con un error que no nombra el toolchain.
  `AGENTS.md` ya documenta el síntoma y la comprobación.
- **[`**/Package.swift` saca de SwiftLint cualquier manifiesto futuro]** → Es lo que se busca: la
  longitud de un manifiesto generado crece con el número de targets. El coste de perder las demás
  reglas está dicho en `proposal.md`.
- **[El generador imprime una ruta que aquí no existe]** → Dice «añade `case <nombre>` a
  `App/AppRoute.swift`», y aquí el enum está en `Domain`. La guía nombra la ruta buena; el defecto va
  a AppFoundation.
- **[AppFoundation arregla también `AppRoute` en `Domain`]** → El paso del `case` sobra. La versión
  que nombra la guía avisa a quien suba de versión. Quitarlo es otro cambio.
