# carrito Specification

## Purpose

Leer el carrito de un usuario y enseñarlo —qué lleva, cuántas unidades y lo que va a pagar
con el descuento aplicado—, y editarlo: cambiar la cantidad de una línea y quitarla. Lo que
se ve tras una edición es lo que respondió el servidor, y las ediciones NO persisten en él:
es un límite de DummyJSON, declarado en su requisito, y al volver a abrir la pantalla
reaparece el carrito que tenga el servidor. Añadir productos o borrar el carrito entero no es
de esta capacidad.

La identidad del usuario NO la resuelve esta capacidad: la recibe. `CartFeature` no puede
importar `ProfileFeature` (R13), y subir un proveedor de identidad a `Networking` habría
creado superficie compartida para un solo consumidor, así que el `userId` viaja en
`AppRoute.cart(userId:)` desde la pantalla que ya lo tiene cargado. El coste, que es
decisión y no descuido: no se puede abrir por deep link sin ese id. El día que haya un
segundo origen, subir el proveedor será su propio cambio.

## Requirements

### Requirement: El carrito se lee, se muestra vacío o falla, y siempre se sale de la carga

La pantalla de carrito SHALL cumplir:

1. SHALL mostrar, por cada línea, su cantidad y su total con descuento — no solo el precio
   unitario: un carrito que enseña precios sueltos no dice lo que se va a pagar. Y esa
   cifra SHALL poder reconciliarse con lo que tiene al lado, en los términos del requisito
   «La rebaja que se aplica se ve, y cuando no la hay no se inventa»: enseñar el total real
   junto a un precio unitario que no lo explica cumple la letra de esta cláusula y aun así
   deja al usuario delante de una cuenta que no le sale.
2. Un usuario **sin carritos** SHALL producir un estado vacío explícito, distinto de un
   error y distinto de una lista vacía sin explicación.
3. Un fallo de red SHALL llegar a la pantalla como `CartError`, nunca como `APIError` ni
   como DTO.
4. Todo camino de salida —éxito, vacío, error y cancelación— SHALL dejar la fase en un
   estado del que se pueda salir.

La cuarta no es redundante con la spec `plataforma`: aquella fija qué pasa con la
cancelación; esta exige que **ningún** camino deje la pantalla colgada, incluido el vacío,
que es el que se olvida porque no parece un caso.

#### Scenario: Carrito con líneas

- **WHEN** el usuario tiene al menos un carrito
- **THEN** se listan sus líneas con cantidad y total con descuento
- **AND** la fase queda cargada

#### Scenario: Usuario sin carritos

- **WHEN** la respuesta no trae ningún carrito
- **THEN** la pantalla muestra su estado vacío
- **AND** no muestra error

#### Scenario: Fallo de red

- **WHEN** la petición falla
- **THEN** la pantalla muestra el `ScreenError` de `CartError`
- **AND** ofrece reintentar solo si el error es reintentable

### Requirement: La rebaja que se aplica se ve, y cuando no la hay no se inventa

Ninguna cifra que la pantalla de carrito presente como «lo que se paga» SHALL quedar sin
explicación al lado de las cifras con las que aparentemente no cuadra. La pantalla SHALL
cumplir:

1. Una línea con descuento SHALL mostrar, junto al importe que se paga, el importe **sin**
   descuento del que sale, marcado como ya no vigente.
2. El total del carrito SHALL desglosarse en subtotal, descuento y total cuando el carrito
   lleva descuento.
3. Cuando no hay descuento —el importe con y sin descuento coinciden **redondeados a
   céntimos**, esto es, se presentarían al usuario como la misma cifra— la pantalla SHALL
   NOT mostrar importe tachado, fila de descuento ni un descuento de cero. Una pantalla que
   explica una rebaja inexistente es tan confusa como la que oculta la real, y aquí se paga
   en cada línea de cada carrito sin promoción.

   El redondeo es parte del requisito, no un detalle de quien lo implemente: la condición
   se mide sobre **la cifra que se ve**. Medida sobre los importes en crudo, dos valores
   que difieren por debajo del céntimo obligarían a tachar un importe idéntico al de al
   lado y a enseñar «Descuento −0,00 $» — la cláusula incumplida por el propio redondeo del
   formateador. Y al revés, para que no se lea como una licencia para descartar rebajas
   pequeñas: una diferencia de un céntimo entero SÍ es un descuento y SHALL verse.
4. Un importe con descuento **mayor** que el importe sin descuento no es una rebaja: es un
   recargo, y la pantalla SHALL NOT tacharlo ni desglosarlo — SHALL mostrar solo lo que se
   paga, igual que cuando los dos coinciden. Esta pantalla no tiene diseño para enseñar un
   recargo, y decorarlo como una rebaja diría lo contrario de lo que pasa: el importe menor
   tachado ENCIMA del mayor, y un «Descuento» que suma. La condición es direccional por eso,
   no una comparación simétrica de «difieren».
5. El importe sin descuento SHALL venir de la respuesta de la API, no de multiplicar
   cantidad por precio unitario ni de sumar las líneas. Es la misma razón por la que el
   total con descuento tampoco se recalcula: si la aritmética y la API discreparan, manda
   la API, que es quien cobra — y presentar un «antes» que el servidor no ha dicho es
   inventarse el número del que se deriva la rebaja.
6. Un lector de pantalla SHALL oír qué es cada cifra de la línea y del pie, no la lista de
   números. El tachado es una señal exclusivamente visual: sin nombrarlas, la fila pasa de
   dos importes ambiguos a tres, y para quien usa VoiceOver este cambio sería un
   empeoramiento, no un arreglo.

El requisito habla de lo que la pantalla **significa**, no de cómo se llamen sus campos: se
cumple igual si el importe sin descuento se decora tachándolo o de otra forma, mientras siga
leyéndose como el precio anterior y no como un segundo cargo.

#### Scenario: Línea con descuento

- **WHEN** una línea tiene un importe con descuento MENOR que su importe sin descuento
- **THEN** la fila muestra las dos cifras
- **AND** la que no se paga se distingue de la que sí

#### Scenario: Línea sin descuento

- **WHEN** el importe con descuento de una línea coincide con el importe sin descuento una
  vez redondeados a céntimos
- **THEN** la fila muestra una sola cifra
- **AND** no aparece ningún importe tachado

#### Scenario: Una línea rebajada un solo céntimo

- **WHEN** el importe con descuento de una línea es un céntimo menor que el importe sin
  descuento
- **THEN** la fila muestra las dos cifras
- **AND** la rebaja no se descarta por pequeña

#### Scenario: Un importe que sube en vez de bajar

- **WHEN** el importe con descuento de una línea o de un carrito es mayor que su importe sin
  descuento
- **THEN** la pantalla muestra solo el importe que se paga
- **AND** no lo presenta como una rebaja

#### Scenario: El pie de un carrito con descuento

- **WHEN** el carrito tiene un total con descuento MENOR que su total sin descuento
- **THEN** el pie muestra subtotal, descuento y total
- **AND** el descuento es la diferencia entre los otros dos

#### Scenario: El pie de un carrito sin descuento

- **WHEN** los dos totales del carrito coinciden redondeados a céntimos
- **THEN** el pie muestra solo el total
- **AND** no aparece ninguna fila de descuento

#### Scenario: La API manda un importe que no es cantidad por precio

- **WHEN** la respuesta trae un importe sin descuento que no coincide con multiplicar la
  cantidad por el precio unitario
- **THEN** la pantalla enseña el importe que dijo la API
- **AND** no la multiplicación

#### Scenario: La misma línea leída por VoiceOver

- **WHEN** un lector de pantalla recorre una línea con descuento
- **THEN** oye nombradas las cifras que la componen: el precio unitario, el importe
  anterior y el que se paga
- **AND** no una sucesión de importes sin decir cuál es cuál

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
