## MODIFIED Requirements

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

## ADDED Requirements

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
