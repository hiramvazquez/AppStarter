## Context

El motivo y la medición del generador están en `proposal.md`, «Why». Lo que condiciona el cómo:

- `huecos-del-generador-en-el-repo`, archivado el 2026-09-17, escribe en `AGENTS.md`, sección «Si
  vas a añadir una feature nueva», qué registra el generador y **dos** pasos manuales: el `case` de
  `AppRoute` y `xcodegen generate`. Los otros dos que ese acuerdo esperaba —la coma de
  `App/AppModule.swift` y el formato— dejaron de hacer falta al subir a AppFoundation 1.4.2. Ese
  cambio validó la guía siguiéndola en un worktree desechable, y salió verde.
- `Scripts/check-showcase.sh`, que CI ejecuta en cada push a `main` y en cada PR, comprueba cada cita
  `` `Símbolo` en `fichero:línea` `` del README con un margen de ±3 líneas. Una de ellas es
  `` `CoordinatorView` en `App/RootView.swift:69` ``. El README tiene más referencias a líneas de
  `App/RootView.swift` sin ese formato, y el script no las mira.
- El comentario de `struct RootView` está en inglés, como el resto de comentarios de `App/`. El
  README está en español. SwiftLint no mide la longitud de los comentarios (`ignores_comments: true`),
  pero `.swift-format` fija `lineLength: 120`.

## Goals / Non-Goals

**Goals:**

- Que la lista de pasos manuales exista en un solo sitio, y que README y comentario apunten a él.
- Que el cambio no desplace ninguna línea de código de `App/RootView.swift`.

**Non-Goals:**

- Que el README explique por qué existe cada paso manual. Eso es de `AGENTS.md` y de su cambio.

## Decisions

### Los pasos manuales no se copian: README y comentario remiten a `AGENTS.md`

«Añadir una feature nueva» y el comentario de `RootView` nombran la sección
`AGENTS.md` § «Si vas a añadir una feature nueva» y no repiten sus pasos.

*Por qué:* los pasos son lo que más cambia. Dependen de los defectos de cada versión del
generador, y la validación de `huecos` aún puede reescribirlos. Una segunda copia se queda vieja
por su cuenta, igual que se quedaron estos dos textos. Remitiendo por el nombre de la sección, el
texto que aquí se escribe no depende de la redacción final de la guía.

*Alternativa:* copiar los dos pasos al README, para que se entienda sin abrir otro fichero. Pero
cada cambio del generador obligaría a tocar dos sitios, y este cambio existe porque eso no pasó.

### Lo que hace el generador sí se escribe en el README, con su versión

El párrafo de «El kit, usado de verdad» enumera qué edita el generador y con qué marker. Nombra
AppFoundation 1.4.2.

*Por qué:* es el escaparate del kit, y ese párrafo existe para decir qué hace el generador. Quitarlo
lo deja vacío. Lo que enumera son capacidades del plugin, leídas en `registerAppWiring` y
`registerAppModule` y medidas (ver `proposal.md`). No son pasos que dependan de sus defectos. La
versión escrita hace que un `grep -rn` de la versión resuelta —hoy `1\.4\.2`— encuentre el
README, el comentario y la guía de `AGENTS.md` juntos.

*Alternativa:* que el párrafo también remita a `AGENTS.md` sin enumerar nada. Hay una copia menos,
pero el lector del README pierde lo único que el párrafo le cuenta.

### El comentario de `RootView` conserva su número de líneas

El párrafo nuevo ocupa las mismas cinco líneas que el de hoy (23-27), sin pasar de 120 columnas.
`struct RootView` sigue en la línea 28.

*Por qué:* así ninguna cita del README a una línea de `App/RootView.swift` se mueve. La que CI
comprueba (`:69`) cabe en el margen de ±3 con hasta tres líneas de diferencia, pero las que no
comprueba nadie se desplazarían en silencio. Con el mismo número de líneas, no hay nada que
comprobar.

*Alternativa:* escribir el párrafo con las líneas que pida y actualizar después las citas del README.
Pero eso toca líneas del README fuera del alcance, y algunas ya estaban mal antes de este cambio
(ver `proposal.md`, «Fuera de alcance»).

### Se aplica sobre `huecos-del-generador-en-el-repo` archivado, no junto a él

La primera tarea comprueba que ese cambio está archivado en la rama y que `AGENTS.md` ya tiene su
guía. Si no, el apply se para.

*Por qué:* los dos textos remiten a una sección que, hasta entonces, dice lo contrario: que el
destino de `RootView.swift` se añade a mano. Los ficheros de los dos cambios no se solapan, así que
el orden no es por conflictos de merge. Es para que la remisión apunte a una guía correcta.

*Alternativa:* meter estos dos ficheros en `huecos` con `/opsx:update`. Pero ese cambio los dejó
fuera a propósito, y el owner los ha pedido como cambio aparte.

### La medición del generador no se repite al aplicar, salvo que cambie la versión

La tarea 1.2 comprueba qué versión de AppFoundation fijan los dos `Package.resolved`. Si es la
misma con la que se midió, vale la medición. Si no, se relee `MultiMode.swift` en la versión nueva
y se repite la medición antes de escribir nada, y si el comportamiento cambió se corrige este
acuerdo por escrito.

*Y eso es lo que pasó*: la versión resuelta es la 1.4.2, no la 1.4.1. Ver la renegociación al final
de `proposal.md`.

*Por qué:* la versión la fija `Package.resolved`, y la medición ya está en `proposal.md` con la
orden y la salida. Repetirla con la misma versión no puede dar otra cosa.

## Risks / Trade-offs

- **[`huecos` cambia el nombre de la sección]** → La remisión apuntaría a una sección que no existe.
  La tarea 1.1 busca la sección por su nombre exacto antes de escribir.
- **[`huecos` se abandona]** → Este cambio queda bloqueado en la tarea 1.1, sin nada escrito. Toca
  decidir si se aplica sobre otra guía, y eso es renegociar el acuerdo.
- **[Cinco líneas no bastan para decir lo mismo]** → El texto se recorta: los markers, la frase
  sobre `AppRoute` y la remisión. El porqué de `AppRoute` en `Domain` ya está en el comentario de
  `Domain/AppRoute.swift`, y no hace falta repetirlo.
- **[El README remite a un fichero pensado para agentes, y hasta hoy no lo nombraba]** →
  `AGENTS.md` está en español, en la raíz, y se lee sin el plugin. La remisión da la ruta y el
  nombre exacto de la sección. Es el coste de tener una sola lista.
