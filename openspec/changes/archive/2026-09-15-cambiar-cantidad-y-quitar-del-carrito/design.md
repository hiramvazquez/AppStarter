## Context

El motivo y las mediciones contra DummyJSON están en `proposal.md` § Why. Esto es lo que
condiciona el cómo:

- `CartLogic` no guarda estado: es `nonisolated final class` y `CartModule` la registra como
  `.transient`. El carrito que se ve vive en `CartViewModel.cart`.
- `performActivity(style:errorHandling:)` (AppFoundation 1.3.x) mantiene `phase` y pinta un
  indicador de `activity` encima del contenido. Hace tres cosas que importan aquí:
  - Al arrancar una actividad, **cancela la que estuviera en vuelo**.
  - Presenta el error por `ErrorPresenting`; con `.banner`, solo se ve el `message`.
  - Ante una cancelación reconocida sale con un `return` seco, **sin `stopActivity()`**. Es
    la misma trampa que `performLoad` tiene con `phase` y que la spec `plataforma` ya
    documenta.
- El estilo `.overlay` se pinta como `Color.black.opacity(0.25)` sobre el contenido
  (`ScreenContainer.activityView`), y un `Color` con opacidad recibe los toques. Es decir:
  hoy bloquea la lista, pero por un detalle de pintado del kit, no por contrato.
- `AGENTS.md`: una llamada a API es un Service.
- Un snapshot recién grabado siempre sale verde. La fila de carrito ya se partió una vez por
  ancho, lo tumbó la imagen y no el test (`CartView.swift`, el comentario de `CartLineRow`).
- `AppUITests` no entra en la firma de `/kit-verifica` (`kit.conf`).

## Goals / Non-Goals

**Goals:**

- Que cada petición de edición lleve toda la intención del usuario, sin depender de lo que
  el servidor recuerde (que es nada).
- Que lo que se ve salga siempre de una sola respuesta del servidor, nunca de una mezcla.
- Que el bloqueo, el fallo y la cancelación de una edición se fijen con `swift test`, no con
  el overlay ni con un UI test.

**Non-Goals:**

- Encolar ediciones o agrupar pulsaciones seguidas del control de cantidad.
- Tocar `CartError`, su copy o `AppCancellationRecognizer`.
- Cambiar el modelo de dinero, que sigue siendo `Double`.

## Decisions

### Cada edición manda la lista completa, con `merge: false` explícito

El cuerpo es `{"merge": false, "products": [{"id": 162, "quantity": 2}, …]}`, construido a
partir de `cart.lines` en su orden, con el cambio ya aplicado: la cantidad sustituida, o la
línea omitida.

*Alternativa descartada:* `merge: true` con solo la línea cambiada. Según el código de
DummyJSON sustituye la cantidad, así que valdría para cambiarla, pero no para quitar. Y como
el servidor calcula sobre el carrito original congelado, la segunda edición devolvería el
original con ese solo cambio: la primera, deshecha. Es la cláusula 3 del requisito
incumplida.

*Alternativa descartada:* `quantity: 0` para quitar. La línea se queda en el carrito, a cero:
`isNumber` acepta el 0.

*Alternativa descartada:* `DELETE /carts/{id}`. Borra el carrito entero, no una línea.

`merge: false` ya es el default del servidor, y aun así **se manda explícito**. Si ese
default cambiara, «sustituir» pasaría a «fusionar» y las líneas quitadas volverían sin que
nada avisara. Además el servidor evalúa `if (merge)`, así que un `"false"` en string contaría
como verdadero. Un `Bool` de Swift se codifica como `false` de JSON, y lo fija el test del
cuerpo.

El orden importa: con `merge: false` el servidor devuelve las líneas en el orden de la
petición. Mandarlas en el orden del carrito evita que las filas salten de sitio.

### Un servicio aparte, con DTO propio

`Services/CartUpdateService.swift` contiene:

- `UpdateCartRequest: BaseRequest`: `PUT /carts/{cartId}`, con `Body` y `Response` propios.
- `CartLineQuantity`: `id` y `quantity`, `Sendable` y `Equatable`, para que los mocks puedan
  asertar la lista recibida.
- `CartUpdateServicing`:
  `func replaceLines(cartId: Int, with lines: [CartLineQuantity]) async throws(APIError) -> Cart`.
- `CartUpdateService: CartUpdateServicing, EndpointService`.

La `Response` decodifica `id`, `total`, `discountedTotal`, `totalQuantity` y, por línea, `id`,
`title`, `price`, `quantity`, `total`, `discountedPrice` y `thumbnail`. Todos son no
opcionales salvo `thumbnail`, por la misma razón que el `GET`. `discountedPrice` se mapea a
`CartLine.discountedTotal`, porque es el importe de la línea entera y no un precio unitario:
medido, `2 × 29.99` con un 12,13 % da `53`.

*Alternativa descartada:* un método más en `CartService`. `AGENTS.md` pide un Service por
llamada, y donde discrepa con lo que haya en otra feature, gana `AGENTS.md`.

*Alternativa descartada:* reutilizar `GetUserCartsRequest.LineDTO` con `discountedTotal` y
`discountedPrice` opcionales. Sería un DTO en el que debe venir exactamente uno de los dos
campos, y que, si faltaran ambos, degradaría en silencio. Es justo lo que `LineDTO.total`
documenta que no se hace. Con dos DTOs, los dos campos siguen siendo obligatorios.

El mapeo DTO → `CartLine` queda escrito en los dos servicios y difiere en un campo. No se
extrae de antemano: habría que meter un protocolo sobre dos DTOs para compartir seis
asignaciones. Si `/kit-duplicados` lo marca al implementar, se decide con el informe
delante.

### `Cart.id` es opcional, y solo `Cart.empty` no lo tiene

`public let id: Int?` es parámetro obligatorio del `init`, sin default, igual que `total`.
Vale `nil` únicamente en `Cart.empty`: un usuario sin carritos no tiene carrito que editar.
Si le llega un carrito sin `id`, la `Logic` lanza `CartError.notFound`, cuyo copy («No
encontramos el carrito de esta cuenta.») describe exactamente esa situación.

*Alternativa descartada:* `Int` con `Cart.empty` en `id: 0`. Es un id mágico que acabaría en
`PUT /carts/0`, y el 404 lo daría el servidor en vez del modelo.

*Alternativa descartada:* `id: Int? = nil` por defecto. Tocaría menos tests, pero un servicio
podría olvidarse de mapearlo: todas las ediciones fallarían con `notFound` y todos los tests
de carga seguirían verdes.

Un carrito que se queda sin líneas tras quitar la última conserva su `id`; lo que dispara el
estado vacío es `isEmpty`.

### La `Logic` compone la lista y el `ViewModel` le pasa el carrito que ve

```swift
func setQuantity(_ quantity: Int, ofLine lineId: Int, in cart: Cart) async throws -> Cart
func removeLine(_ lineId: Int, from cart: Cart) async throws -> Cart
```

La `Logic` sigue sin estado: recibe el carrito que la pantalla enseña, compone la lista,
llama al servicio y traduce el error con `CartError.from(_:)`, que ya existe
(`TransportMappable`). Si la cantidad es menor que 1, devuelve `cart` tal cual y no llama al
servicio. No lanza, porque desde la pantalla no se puede provocar (el control se para en 1),
y un banner por eso sería ruido. Un `lineId` que no esté en el carrito no tiene caso
especial: la lista sale igual, desde la UI no se alcanza, y un `guard` sería código para
nadie.

*Alternativa descartada:* que la `Logic` guarde el carrito vigente. Dejaría de ser
transitoria y habría dos fuentes de verdad, ella y `CartViewModel.cart`.

### Pesimista: nada cambia hasta que responde el servidor

*Alternativa descartada:* edición optimista con marcha atrás si falla. Entre la pulsación y
la respuesta, la fila enseñaría la cantidad nueva al lado de importes de la anterior (`2 ×`
junto a `105,41 $`, que era de 4 unidades), y es la cuenta que no sale y que prohíbe la
cláusula 1 del primer requisito. Además, deshacer exige guardar el carrito anterior, que es
estado nuevo. El coste de ser pesimista es un viaje de red por pulsación con el indicador
encima, y se acepta.

### Actividad secundaria con overlay y banner, y el bloqueo en el `ViewModel`

Las dos acciones van por `performActivity(style: .overlay, errorHandling: .banner)`. Con
éxito, `vm.cart = actualizado` y, si ha quedado vacío, `vm.setEmpty()`. `phase` no pasa por
`.loading`, así que el carrito sigue a la vista.

Las dos acciones empiezan con `guard !isPerformingActivity else { return }`. El overlay ya
bloquea los toques, pero hacen falta las dos cosas, por tres razones:

- El bloqueo del overlay es un detalle de pintado del kit, no un contrato (§ Context).
- Sin la guardia, una segunda edición cancelaría la primera en vuelo (`performActivity` lo
  hace al arrancar) y mandaría una lista calculada sobre `vm.cart`, que aún no incluye la
  primera. Sería la cláusula 3 incumplida.
- La guardia se prueba en `swift test`; el overlay, solo con un UI test fuera de la firma.

*Alternativa descartada:* estilo `.inline`. Deja el contenido interactivo y reabre, a la
vista del usuario, la concurrencia que la guardia cierra.

*Alternativa descartada:* encolar ediciones. Es más estado y una decisión de UX que nadie ha
pedido.

**El banner no nombra la operación.** Enseña el `message` del `CartError`, por ejemplo
«Inténtalo de nuevo más tarde.». El contexto lo da la cantidad, que vuelve a su valor
anterior. Un «No se pudo actualizar el carrito» obligaría a sobrescribir
`handleActivityError` y a escribir copy nuevo para una sola pantalla. Si se queda corto, es
otro cambio.

### La cancelación de una edición se trata igual que la de la carga

```swift
} catch CartError.cancelled {
    if !Task.isCancelled { vm.stopActivity() }
    throw CartError.cancelled
}
```

Sin esto, una cancelación de red deja el overlay puesto para siempre. Y aquí es peor que en
la carga: el overlay se come los toques y la guardia rechaza cualquier edición, así que la
pantalla queda muerta del todo. La condición `!Task.isCancelled` cubre el caso de que la
pantalla ya se haya retirado (`cancelInFlightWork()`): no queda nadie a quien desbloquear.

No hace falta un caso nuevo en `CartError` ni tocar `AppCancellationRecognizer`:
`CartError.cancelled` ya está registrado. El default `cancelsInFlightWorkOnRemoval: true` se
queda como está, porque una edición sin pantalla no tiene a quién enseñar su resultado y el
servidor tampoco la iba a guardar. La spec `plataforma` solo pide declararlo a quien se
aparta del default.

### La fila: control de cantidad, «Quitar» al deslizar y acciones de accesibilidad

- **Cantidad**: un `Stepper` sobre un `Binding` cuyo `get` lee `line.quantity` y cuyo `set`
  manda `.setQuantity`, con rango inferior en 1 (el «−» se desactiva solo). No hay `@State`
  local: la cifra que se ve es la del modelo, y por tanto la del servidor (§ Pesimista).
- **Dónde va** el control lo decide la imagen, como ya pasó con los importes apilados. El
  primer intento lo pone bajo `4 × 29,99 $`. Si con el título largo del snapshot algo se
  parte, se baja a una segunda fila.
- **Quitar**: `.swipeActions(edge: .trailing)` con un botón «Quitar», no `.onDelete`. La
  etiqueta es explícita en español y no depende de los offsets del `ForEach`.
- **Accesibilidad**: la fila conserva `.accessibilityElement(children: .combine)` y el label
  de `CartCopy`. Con `.combine` no hay garantía de que el `Stepper` interior siga siendo
  ajustable, así que se añaden explícitamente `.accessibilityAdjustableAction` (subir y
  bajar; bajar en 1 no hace nada) y `.accessibilityAction(named: "Quitar")`.

Esto último **no lo cubre la firma**, y se dice aquí para que el acuerdo no afirme de más.
Ningún test de `swift test` ni ningún PNG ve acciones de accesibilidad. Se comprueba a mano en
el simulador (criterio de aceptación del proposal), igual que quedó abierta la mitad de
`CartCopy` en el cambio del descuento.

## Risks / Trade-offs

- **[Las ediciones no persisten]** → La spec lo declara como límite y tiene escenario. No hay
  nada que mitigar en código.
- **[Céntimos que cambian en líneas no tocadas, y rebajas que desaparecen por redondeo]** →
  Es la decisión del owner (proposal). Con la fórmula del código de DummyJSON, sin medirlo
  en vivo, Baseball Ball (`2 × 8.99 = 17.98`, 1,71 %) pasaría de `17.67` a
  `Math.round(17.67) = 18`, por encima de su `total`. La cláusula 4 del requisito de la
  rebaja ya impide decorar ese importe como rebaja, así que la fila enseña solo `18,00 $`.
- **[El servidor en vivo deja de mandar `discountedPrice`]** → El campo no es opcional: la
  edición falla con su banner (`unknown`, por decodificación) en vez de pintar ceros. El test
  con bytes reales lleva la fecha de la medición.
- **[La fila no cabe con el control de cantidad]** → Se regraban los snapshots, se mira el PNG
  y queda la salida de bajar el control a una segunda fila (tarea propia).
- **[Un botón con `role: .destructive` en `swipeActions` anima la fila fuera antes de la
  respuesta]** → Se comprueba en el simulador. Si pasa, el botón va sin rol y con
  `.tint(.red)`: la fila no puede irse antes que el dato.

  *Enmendado el 2026-09-15.* La comprobación de la 5.4 no fue concluyente (con éxito, el
  servidor responde antes de la captura siguiente), y el revisor señaló el caso que importa
  —un `PUT` de «Quitar» que FALLA— sin poder reproducirlo. El owner decidió no esperar a
  reproducirlo: **el botón va sin rol y con `.tint(.red)`**, que es la salida que este riesgo ya
  preveía, aplicada por precaución y no por un fallo visto.
- **[«Quitar» sale dos veces en el rotor de VoiceOver]** (la acción de deslizar y la
  explícita) → Se comprueba en la misma pasada manual y se deja una.
- **[Una petición por pulsación del control]** → Se acepta. El overlay y la guardia las
  serializan; agruparlas queda fuera.
- **[Una carga y una edición a la vez]** → No se alcanza: las filas solo existen en
  `.content`, y la carga las tapa con su indicador a pantalla completa. Queda declarado, sin
  test.
- **[Todo `Cart(...)` del repo tiene que nombrar el `id`]**, también en suites que no prueban
  ediciones → Es el precio de un parámetro obligatorio, el mismo que se pagó con `total`.
