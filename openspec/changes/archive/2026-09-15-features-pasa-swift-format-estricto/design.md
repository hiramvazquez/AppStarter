## Context

El motivo, las cifras y la base acordada (`94deb9c`) están en `proposal.md`. Lo que condiciona el
cómo:

- `swift format format` es determinista: su salida depende del fichero, de `.swift-format` y de la
  versión de swift-format. `.swift-format` tiene `respectsExistingLineBreaks: true`. En el ensayo
  sobre una copia (2026-09-15) cambiaron exactamente los 14 ficheros con avisos.
- No todo lo que cambia es espacio en blanco. `TrailingComma` quita comas, `OrderedImports` mueve
  líneas, y `AddLines` pasa a su propia línea el `"""` de apertura de tres literales multilínea. El
  valor de un literal multilínea de Swift depende de la sangría de su `"""` de cierre.
- Versiones, medidas el 2026-09-15:
  - CI: el job de paquetes elige el Xcode más nuevo del runner `macos-15`. En el run
    `35006556028` fue Xcode 26.3, con Swift 6.2.4.
  - Local: el Xcode 26.6 trae swift-format 6.3.0, y el `swift` de swiftly trae el 6.3.3. Sobre una
    copia de `dfc20bc`, los dos dan los mismos 78 avisos, el mismo resultado al formatear y 0 avisos
    después.
  - En esta máquina no hay ningún toolchain 6.2. swift-format se compila desde el tag
    `swift-6.2.4-RELEASE` (ver «La versión de CI…», abajo). Sobre `dfc20bc` da los mismos 78 avisos,
    el mismo resultado al formatear (`diff -r` vacío frente a la 6.3.3) y 0 avisos después. Sobre
    el `Packages/Features` de `94deb9c` también formatea igual que la 6.3.3 y deja 0 avisos. En
    `Packages/Platform` da 0.
- El paso de CI corre con `bash -e`, y SwiftLint va primero: mientras SwiftLint falle, CI no dice
  nada de swift-format.
- `lint-estricto…` está commiteado como `94deb9c`, hijo directo de `dfc20bc`, en su propia rama,
  sin archivar ni fusionar en `main`. Su `Packages/Features` es idéntico al árbol sin commitear
  sobre el que se simuló en la tarea 4.1.

## Goals / Non-Goals

**Goals:**

- Que la orden de swift-format de CI dé 0 avisos en `Packages/Features`, con un diff que se pueda
  demostrar que es solo formato y que cualquiera pueda rehacer.
- Que este cambio no se adelante a `lint-estricto…`: parte de su commit y no entra en `main` antes
  que él.

**Non-Goals:**

- Que el paso de CI quede en verde antes de que entren los dos cambios.
- Impedir que el formato se vuelva a romper, que sería meter swift-format en `kit.conf` y queda
  fuera de alcance.

## Decisions

### Solo la herramienta, sin tocar nada a mano

El diff es el que deja una pasada de `swift format format --in-place` con la configuración de CI.
Si quedara algún aviso sin resolver, o el resultado pidiera un retoque, se para y se renegocia el
acuerdo por escrito.

*Por qué:* así el cambio es reproducible. Quien lo revise, o quien tenga que rehacerlo tras otro
cambio, corre la misma orden y obtiene el mismo árbol.

*Alternativa descartada:* corregir los avisos a mano. Llega al mismo sitio, con más riesgo de colar
algo que no es formato, y no se puede rehacer con una orden.

### «Solo formato» se demuestra con un script, no con `git diff -w`

Un script de un solo uso compara cada fichero antes y después:

- sin espacios, sin la coma final antes de `]` o `)` y con los `import` ordenados, el texto es
  idéntico;
- cada literal `"""` da los mismos bytes, calculados con la regla de Swift: a cada línea se le
  quita la sangría del `"""` de cierre.

Además se lee el diff entero. En el ensayo sobre `dfc20bc` salieron 148 líneas cambiadas, con los
14 ficheros y los 3 literales iguales.

*Alternativa descartada:* `git diff -w`. Enseña como cambio las comas, los imports y los `"""`
movidos, y no ve un cambio de sangría dentro de un literal, que sí cambia su valor.

### El orden con `lint-estricto…`: se adapta el que entre segundo

Los dos cambios se complementan, y cualquier orden sirve siempre que el segundo haga su parte:

- **Si este entra primero:**
  - A `lint-estricto…` le quedan 19 violaciones de SwiftLint en vez de 20, porque la línea 94 de
    `CartUpdateServiceTests.swift` ya está partida: su tarea 1.1 lo detecta y su 2.2 ya está hecha.
  - Las líneas 124, 174 y 220 que nombra no se mueven (medido sobre la copia).
  - Su código nuevo tiene que pasar la orden de swift-format, o el paso vuelve a rojo por formato.
- **Si aquel entra primero:** este se rehace con la misma orden sobre el árbol nuevo. Antes de
  aplicar se actualizan por escrito en este acuerdo la tabla de ficheros y los números de la línea
  base, que habrán cambiado.
- **Si las dos ramas se fusionan tal cual:** git da conflicto en `CartUpdateServiceTests.swift:94`
  (la misma línea) y en `ProductsViewModelTests.swift:219-220` (líneas contiguas). Se resuelve
  quedándose con el código de `lint-estricto…` y volviendo a pasar la orden de formato, no
  eligiendo trozos a mano.

*Por qué este cambio no toca `lint-estricto…`:* ese acuerdo es de quien lo lleva. Aquí queda
escrito qué cambia para él.

*Alternativa descartada:* no partir la línea 94 de `CartUpdateServiceTests.swift`, para no mover el
20 de aquel cambio. El `LineLength` de swift-format seguiría ahí y el objetivo no se cumpliría.

*Decidido el 2026-09-15: entra primero `lint-estricto…`.* Lo eligió el owner en la tarea 4.1, al
ver que ese cambio iba por 20 de 21 tareas, sin commitear, y ya había tocado los tres ficheros
compartidos. Simulado sobre una copia de su árbol, formatear encima:

- cambia los mismos 14 ficheros, que pasan de 78 avisos a 84;
- deja 0 avisos, con la 6.3.3 y con la 6.2.4, que formatean igual;
- deja 0 violaciones de SwiftLint en el alcance de CI;
- difiere del formato de la primera pasada solo en las ediciones de aquel cambio.

Las cifras definitivas se miden sobre `main` cuando entre.

*Renegociado el mismo día: la base es `94deb9c`, no `main`.* Al retomar, `lint-estricto…` estaba
commiteado en su rama, pero no en `main`, y el owner eligió partir de ese commit en vez de esperar.
De las tres situaciones de arriba queda solo «aquel entra primero», con otra base: esta rama se trae
a `94deb9c` con fast-forward y el formato se rehace encima, sin conflictos. A cambio, dos reglas:

- esta rama no se fusiona en `main` antes que `lint-estricto…`, porque se llevaría `94deb9c` sin su
  revisión ni su archivado;
- antes de fusionarla, `Packages/Features/Sources` y `Packages/Features/Tests` en `main` tienen que
  ser iguales que en `94deb9c`. Si la revisión o el archivado de aquel cambio tocan algo ahí, se
  rehace el formato con la misma orden.

La segunda regla nombraba al principio «`Packages/Features`» entero. Se precisó en la tarea 4.2,
cuando `main` avanzó a `8231924` con una línea de `Package.swift`. Esa línea no la mira la orden de
formato, y con ella la regla literal ya no se podía cumplir.

### La versión de CI se comprueba compilando swift-format 6.2.4

Además de con la versión local, se mide con swift-format compilado desde el tag
`swift-6.2.4-RELEASE` de `swiftlang/swift-format`, con swift-syntax fijado al commit del mismo tag.
Se compila en el scratchpad, fuera del repo, y no se instala nada. Con ese binario:

- la orden de lint de CI da 0 avisos en `Packages/Features` y en `Packages/Platform`;
- formatear la copia de antes deja exactamente el mismo árbol que la versión local.

Si algo no coincide, se para y se renegocia el acuerdo por escrito: habría que decidir con qué
versión se formatea, y eso cambia el plan.

*Por qué:* mientras SwiftLint falle delante, CI no dice nada de swift-format. Sin esta medida, nadie
sabría si el 0 local vale en CI hasta que entraran los dos cambios. Lo eligió el owner el
2026-09-15.

*Alternativas descartadas:*

- Instalar el toolchain 6.2.4 con swiftly: 1,73 GB para usar una sola herramienta.
- No comprobarlo: el riesgo quedaría abierto hasta el primer run de CI con los dos cambios dentro.

## Risks / Trade-offs

- **[`lint-estricto…` cambia `Sources` o `Tests` de `Packages/Features` antes de entrar en `main`]**
  → Lo cubre la segunda regla de la renegociación: se compara con `94deb9c` antes de fusionar, y si
  difiere se rehace el formato.
- **[`main` avanza con otros cambios]** → Ya pasó: `8231924` trae `README.md` y una línea de
  `Packages/Features/Package.swift`. No toca lo que se formatea, pero la firma de esta rama se hace
  sobre `94deb9c` y no incluye esa línea. El árbol que resulte de fusionar se verifica aparte.
- **[Esta rama se fusiona antes que `lint-estricto…`]** → Se llevaría `94deb9c` sin revisar ni
  archivar. Lo impide la primera regla, y el cierre la recuerda.
- **[El runner cambia de Xcode]** → El job elige el Xcode más nuevo de la imagen `macos-15`. Si la
  imagen trae uno con otra versión de Swift, lo medido con la 6.2.4 deja de valer. Fijar la versión
  es tocar el workflow, que queda fuera de alcance.
- **[El formato vuelve a romperse]** → Sin swift-format en `kit.conf`, la firma no lo ve. Queda
  fuera de alcance, y lo dice el proposal.
