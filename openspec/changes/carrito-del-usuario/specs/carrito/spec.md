## ADDED Requirements

### Requirement: El carrito se lee, se muestra vacío o falla, y siempre se sale de la carga

La pantalla de carrito SHALL cumplir:

1. SHALL mostrar, por cada línea, su cantidad y su total con descuento — no solo el precio
   unitario: un carrito que enseña precios sueltos no dice lo que se va a pagar.
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
