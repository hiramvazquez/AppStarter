## ADDED Requirements

### Requirement: Una línea se cambia de cantidad o se quita, y lo que se ve es lo que respondió el servidor

Sobre cada línea, la pantalla de carrito SHALL permitir cambiar la cantidad y quitar la
línea. Y SHALL cumplir:

1. La cantidad SHALL poder fijarse en cualquier entero desde 1. Una cantidad menor que 1
   SHALL NOT llegar al servidor: la API la acepta y deja la línea en el carrito, a cero, que
   es una línea «quitada» que sigue en la lista. Quitar es una acción propia.
2. Quitar una línea SHALL hacerla desaparecer del carrito que se ve. Quitar la última SHALL
   llevar al estado vacío de la pantalla, el mismo que el de un usuario sin carritos, y no a
   una lista vacía sin explicación.
3. Dos ediciones seguidas SHALL acumularse: la segunda SHALL NOT deshacer la primera. Con
   este servidor no sale solo. No guarda nada y calcula cada respuesta sobre el carrito
   original, así que una petición que dijera únicamente «cambia esta línea» devolvería el
   original con ese único cambio.
4. Tras una edición con éxito, la pantalla SHALL enseñar **entero** el carrito que devolvió
   el servidor: líneas, cantidades, importes de cada línea y pie, también los de las líneas
   que no se tocaron. SHALL NOT recalcular nada ni mezclar cifras de la respuesta con cifras
   de antes de la edición. El requisito «La rebaja que se aplica se ve, y cuando no la hay no
   se inventa» se aplica igual a lo que llega de una edición, medido sobre esas cifras.

   Esto tiene un efecto visible, y es una decisión. Al responder a una edición, la API
   redondea a unidades el importe con descuento de cada línea. Tras la primera edición, una
   línea que nadie tocó puede pasar de `10.547,97 $` a `10.548,00 $`, o dejar de enseñar su
   rebaja si el redondeo la sube por encima del importe sin descuento. Conservar las cifras
   de antes en las líneas no tocadas evitaría ese salto, pero a cambio el pie no cuadraría
   con sus líneas, que es lo que prohíbe la cláusula 1 del requisito «El carrito se lee, se
   muestra vacío o falla».
5. La pantalla SHALL NOT cambiar nada de lo que enseña antes de que el servidor responda.
   Una cantidad nueva al lado de importes calculados para la anterior es una cuenta que no
   sale.
6. Mientras una edición espera respuesta, la pantalla SHALL indicarlo y SHALL NOT aceptar
   otra.
7. Una edición que falla SHALL dejar a la vista el carrito tal y como estaba antes de
   intentarla, no una pantalla de error en su lugar, y SHALL avisar con un mensaje que no
   bloquee. El fallo SHALL llegar a la pantalla como `CartError`, nunca como `APIError`.
8. Todo camino de salida de una edición SHALL dejar la pantalla usable, sin indicador de
   edición colgado y aceptando la siguiente: éxito, carrito vacío, fallo y cancelación. Una
   cancelación venida de la red SHALL NOT presentarse como error. Quitar el indicador tras
   una cancelación SHALL hacerse solo si la tarea de esa edición sigue viva, que es lo que la
   spec `plataforma` exige a la carga, aplicado a la edición.
9. Un lector de pantalla SHALL poder cambiar la cantidad de una línea y quitarla desde la
   propia línea, sin depender de un gesto que solo se pueda hacer viendo la pantalla.

**Límite declarado: las ediciones no persisten.** DummyJSON no guarda el resultado de una
edición, medido el 2026-09-15: después de un `PUT`, el `GET` del carrito devuelve el
original. Al volver a abrir la pantalla, o al recargarla tras un error de carga, el carrito
vuelve a ser el que tenga el servidor. Este requisito promete lo que se ve **mientras la
pantalla sigue abierta**, no persistencia. Si algún día el servidor guarda, retirar este
límite será su propio cambio.

#### Scenario: Cambiar la cantidad de una línea

- **WHEN** el usuario sube o baja la cantidad de una línea y el servidor responde
- **THEN** la línea enseña la cantidad y los importes de la respuesta
- **AND** el pie enseña los totales de esa misma respuesta

#### Scenario: Una línea con una sola unidad

- **WHEN** una línea tiene 1 unidad
- **THEN** la pantalla no ofrece bajarla a 0
- **AND** ninguna petición al servidor lleva una cantidad menor que 1

#### Scenario: Quitar una línea

- **WHEN** el usuario quita una línea de un carrito con varias y el servidor responde
- **THEN** esa línea deja de aparecer
- **AND** las demás conservan sus cantidades

#### Scenario: Quitar la última línea

- **WHEN** el usuario quita la única línea del carrito y el servidor responde
- **THEN** la pantalla muestra su estado vacío
- **AND** no muestra error

#### Scenario: Dos ediciones seguidas

- **WHEN** el usuario cambia la cantidad de una línea y, tras la respuesta, quita otra
- **THEN** el carrito que se ve refleja las dos ediciones
- **AND** la primera no se ha deshecho

#### Scenario: Una línea que no se tocó cambia de céntimos

- **WHEN** la respuesta a una edición trae, para una línea que no se tocó, un importe
  distinto del que se veía
- **THEN** la pantalla enseña el importe de la respuesta
- **AND** no conserva el de antes

#### Scenario: Nada cambia antes de la respuesta

- **WHEN** el usuario cambia la cantidad de una línea y el servidor aún no ha respondido
- **THEN** la línea sigue enseñando la cantidad y los importes de antes

#### Scenario: Una edición en vuelo

- **WHEN** hay una edición esperando respuesta
- **THEN** la pantalla indica que está trabajando
- **AND** no acepta otra edición

#### Scenario: Una edición que falla

- **WHEN** la petición de una edición falla
- **THEN** el carrito que se ve es el de antes de intentarla
- **AND** un aviso que no bloquea dice que ha fallado
- **AND** la pantalla acepta la siguiente edición

#### Scenario: Una edición cancelada desde la red

- **WHEN** la petición de una edición falla por cancelación y su tarea sigue viva
- **THEN** no se muestra ningún error
- **AND** la pantalla deja de indicar que trabaja y acepta la siguiente edición

#### Scenario: La pantalla se cierra con una edición en vuelo

- **WHEN** el usuario sale de la pantalla mientras una edición espera respuesta
- **THEN** la edición se cancela
- **AND** su cancelación no toca el indicador de edición ni muestra aviso

#### Scenario: VoiceOver edita una línea

- **WHEN** un lector de pantalla está sobre una línea
- **THEN** puede subir y bajar su cantidad
- **AND** puede quitarla sin salir de la línea

#### Scenario: Volver a abrir el carrito después de editarlo

- **WHEN** el usuario edita el carrito, sale de la pantalla y vuelve a entrar
- **THEN** la pantalla enseña el carrito que devuelve el servidor en ese momento
- **AND** que no conserve las ediciones no se presenta como un error
