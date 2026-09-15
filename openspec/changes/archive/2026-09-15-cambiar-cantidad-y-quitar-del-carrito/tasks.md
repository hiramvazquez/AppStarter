## 1. El carrito trae su id

- [x] 1.1 Añadir `public let id: Int?` a `Cart` (`CartFeature/CartLogic.swift`) como
      parámetro obligatorio del `init`, con `nil` solo en `Cart.empty` y un comentario que
      explique por qué (`design.md` § `Cart.id`). Decodificar `id` en
      `GetUserCartsRequest.CartDTO` y mapearlo en `CartService.fetchCarts`. Poner el `id` en
      todos los `Cart(...)` de `CartFeatureTests`, en la `CartPreviewLogic` de
      `CartView.swift` y en `AppSnapshotTests/CartSnapshotTests.swift`. Verificación:
      `cd Packages/Features && swift build && swift test` en verde.
- [x] 1.2 En `CartServiceTests`, asertar `carts.first?.id == 1` en
      `decodesTotalFromActualJSON` (sus bytes reales ya traen `"id":1`) y en `decodesLines`.
      Verificación: `swift test --filter CartServiceTests` en verde, y en rojo con el mapeo
      del `id` puesto a `nil`.

## 2. La petición de edición

- [x] 2.1 Crear `CartFeature/Services/CartUpdateService.swift` como describe `design.md`
      § Un servicio aparte. Contiene `UpdateCartRequest` (`PUT /carts/{cartId}`, con un
      `Body` que lleva `merge: Bool` y `products: [{id, quantity}]`, y una `Response` con
      `discountedPrice` por línea), `CartLineQuantity`, `CartUpdateServicing` y
      `CartUpdateService` (`EndpointService`). El servicio lleva `discountedPrice` a
      `CartLine.discountedTotal`. Verificación: `swift build` de `Packages/Features` en
      verde, sin `[ArchLint.*]`.
- [x] 2.2 Pasar `/kit-duplicados` con el mapeo DTO → `CartLine` ya escrito en los dos
      servicios, y decidir con el informe delante si se extrae (`design.md` lo deja abierto a
      propósito). Verificación: el commit recoge el resultado y la decisión.

      > Resultado (2026-09-15): el detector no marca el mapeo —los dos cuerpos difieren en
      > `discountedPrice`—, así que no se extrae. Salen dos grupos anteriores a este cambio y
      > ajenos al carrito (`ProductRow.body()` en Favorites/Products/Search, y
      > `UploadsLogic.mapError()` frente a `CatalogError.from()`): fuera de alcance, no se tocan.
- [x] 2.3 Crear `CartFeatureTests/Services/CartUpdateServiceTests.swift` con estos tests:
      - el método es `PUT` y la ruta, `/carts/1`;
      - el cuerpo codificado, leído de `InMemoryTransport.recorded`, lleva `"merge"` como
        booleano `false` y las líneas en el orden en que se pasaron;
      - la respuesta real medida el 2026-09-15 llega a `Cart` con su `id`, sus cantidades y
        el `discountedTotal` de cada línea sacado de `discountedPrice`. Se pasa como bytes
        por `InMemoryTransport`: tres líneas con `discountedPrice` `53`/`10548`/`840`,
        `total` `12959.919999999998`, `discountedTotal` `11441` y `totalQuantity` `8`;
      - `"products": []` decodifica a un carrito vacío con su `id`, no a un error;
      - un 404 llega como `APIError`, sin tocar.

      Verificación: `swift test --filter CartUpdateServiceTests` en verde, y cada test en
      rojo con su mapeo revertido.

## 3. La Logic

- [x] 3.1 `CartLogicProtocol` gana `setQuantity(_:ofLine:in:)` y `removeLine(_:from:)`, y
      `CartLogic.init` recibe `cartUpdateService: any CartUpdateServicing`. Implementar según
      `design.md` § La `Logic` compone la lista:
      - lista completa en el orden del carrito;
      - cantidad menor que 1 → sin llamada, devuelve el mismo carrito;
      - `id` nulo → `CartError.notFound`;
      - fallo → `CartError.from(_:)`.

      En `CartModule`, registrar `CartUpdateServicing` y construir `CartLogic` con los dos
      servicios. Dar las dos operaciones nuevas a `CartLogicMock`, a `CartPreviewLogic` y al
      `StubLogic` de `CartSnapshotTests`. Verificación: `swift build` en verde.
- [x] 3.2 Añadir `CartUpdateServiceMock` a `CartFeatureTests/Mocks/CartMocks.swift`. Guarda
      el `cartId` y las `lines` que recibe. Tests en `CartLogicTests`:
      - cambiar la cantidad manda todas las líneas en orden, con esa cambiada, y devuelve el
        carrito del servicio;
      - quitar manda la lista sin esa línea;
      - quitar una línea del carrito que devolvió un cambio de cantidad conserva ese cambio;
      - con cantidad 0 o negativa, el servicio no recibe ninguna llamada y vuelve el mismo
        carrito;
      - `Cart.empty` lanza `CartError.notFound` sin llamar al servicio;
      - el fallo del `PUT` se traduce así: sin conexión → `offline`, 404 → `notFound`,
        503 → `server`, cancelación → `cancelled`, decodificación → `unknown`.

      Verificación: `swift test --filter CartLogicTests` en verde, y cada rama en rojo con su
      código revertido.

## 4. El ViewModel

- [x] 4.1 `CartViewModel.Action` gana `setQuantity(_ quantity: Int, lineId: Int)` y
      `removeLine(id: Int)`. Cada uno se implementa según `design.md` § Actividad
      secundaria y § La cancelación de una edición:
      - la guardia `!isPerformingActivity`;
      - `performActivity(style: .overlay, errorHandling: .banner)`;
      - la asignación de `cart`;
      - `setEmpty()` si el carrito queda vacío;
      - `catch CartError.cancelled` con `if !Task.isCancelled { vm.stopActivity() }`.

      Verificación: `swift build` en verde.
- [x] 4.2 `CartLogicMock` gana contadores, último argumento y `gate` para las dos
      ediciones. Tests en `CartViewModelTests`:
      - con éxito, `cart` es el devuelto, la fase `.content` e `isPerformingActivity`
        `false`;
      - quitar la última línea deja la fase en `.empty` y sin error;
      - con fallo (`CartError.server`), `cart` sigue como antes, la fase en `.content`, la
        actividad parada y `banner` puesto;
      - con la `gate` cerrada, `cart` todavía no ha cambiado e `isPerformingActivity` es
        `true`;
      - una segunda edición con la primera en vuelo no llega a la `Logic`;
      - después de un fallo, la siguiente edición sí llega.

      Verificación: `swift test --filter CartViewModelTests` en verde, y en rojo al quitar la
      guardia, el `setEmpty()` o la asignación de `cart`.
- [x] 4.3 En `CartViewModelCancellationTests` (`.serialized`), dos tests:
      - una edición que falla con `CartError.cancelled` con la tarea viva deja
        `isPerformingActivity == false`, sin banner y sin error;
      - una edición en vuelo que se desenrolla con `.cancelled` después de
        `cancelInFlightWork()` no toca la actividad: `isPerformingActivity` sigue en `true`.

      Verificación: en verde; el primero en rojo sin el `stopActivity()` y el segundo en rojo
      sin la condición `!Task.isCancelled`.

## 5. La pantalla

- [x] 5.1 `CartContent` recibe cómo mandar acciones, porque hoy solo recibe `cart`.
      `CartLineRow` gana un `Stepper` bajo `4 × 29,99 $`, sobre un `Binding` cuyo `get` lee
      `line.quantity` y cuyo `set` manda `.setQuantity`, con el rango empezando en 1. Adaptar
      las llamadas a `CartContent` en `CartSnapshotTests`. Verificación: `swift build` en
      verde.
- [x] 5.2 Añadir `.swipeActions(edge: .trailing)` con un botón «Quitar» que manda
      `.removeLine`. Sobre el `.accessibilityElement(children: .combine)` que ya tiene la
      fila, añadir `.accessibilityAdjustableAction` (bajar en 1 no hace nada) y
      `.accessibilityAction(named: "Quitar")`. Verificación: `swift build` en verde.
- [x] 5.3 Regrabar `testContentKit` y `testContentSinDescuentoKit`. **Abrir las dos imágenes
      y mirarlas**: tiene que haber control de cantidad en cada línea, ningún importe partido
      y «Apple MacBook Pro 14 Inch Space Grey» sin romper la fila. Si algo se parte, bajar
      el control a una segunda fila, regrabar y volver a mirar. Un snapshot recién grabado
      sale verde diga lo que diga la imagen. Verificación: el commit describe qué se ve en
      cada imagen, y `testEmpty*`/`testError*` siguen en verde sin regrabar.

      > Mirado el 2026-09-15 (iPhone 17). `testContentKit`: control `− +` bajo el
      > `3 × US$540.00` de cada línea, con el «−» desactivado en el MacBook (1 unidad);
      > importes apilados y enteros (`US$1,620.00` tachado sobre `US$1,481.20`, `US$1,999.99`
      > sobre `US$1,798.99`); pie con `4 artículos`, subtotal, `−US$339.80` y `US$3,280.19`.
      > `testContentSinDescuentoKit`: una sola cifra por línea, sin tachado, pie solo con
      > `US$3,619.99`. El título del MacBook ocupa tres líneas, pero YA las ocupaba en la
      > referencia de `HEAD` (comparada lado a lado): el control añade altura a la fila, no
      > parte nada. No hace falta bajarlo a una segunda fila. `testEmpty*`/`testError*` verdes
      > sin regrabar (PNG del 2026-09-07 intactos).
- [x] 5.4 Pasada manual en el simulador contra DummyJSON (Perfil → carrito):
      - subir y bajar una cantidad, quitar una línea y quitar todas hasta el vacío;
      - salir y volver a entrar: tiene que reaparecer el carrito original;
      - con VoiceOver o el Accessibility Inspector sobre una línea, ajustar la cantidad y
        usar «Quitar»;
      - comprobar los dos riesgos de `design.md`. Si la fila se anima fuera antes de la
        respuesta con `role: .destructive`, el botón pasa a ir sin rol y con `.tint(.red)`.
        Si «Quitar» sale dos veces en el rotor, se deja uno.

      Verificación: el commit describe lo observado y lo que se cambió por ello.

      > Pasada del 2026-09-15 (iPhone 17, DummyJSON real, sesión de emilys iniciada por el
      > owner — el agente no teclea contraseñas). Carrito inicial: 4 líneas, `12 artículos`,
      > `US$11,510.81`.
      > - «−» en Blue Frock (4 → 3): la línea pasa a `US$79.00` y las NO tocadas cambian de
      >   céntimos (`US$10,547.97` → `US$10,548.00`, `US$839.76` → `US$840.00`); Baseball Ball
      >   pasa de `US$17.67` con tachado a `US$18.00` SIN tachado — el redondeo al alza que
      >   `design.md` preveía, y la cláusula 4 de la rebaja no lo decora. Pie `US$11,485.00`.
      > - «Quitar» deslizando (botón) en Baseball Ball: fuera; Blue Frock sigue en 3 — la
      >   segunda edición no deshace la primera. `9 artículos`, `US$11,467.00`.
      > - «+» en la moto (3 → 4): `US$14,064.00`; lo anterior intacto. `US$14,983.00`.
      > - Deslizamiento completo en iPhone 6, luego en la moto, luego en Blue Frock: cada una
      >   sale y lo demás se conserva; al quitar la última, el estado vacío del kit (el mismo
      >   que un usuario sin carritos), sin error.
      > - Salir y volver a entrar: reaparece el carrito original (`12 artículos`,
      >   `US$11,510.81`), sin error — el límite declarado.
      > - `role: .destructive`: no se ve la fila irse ANTES de la respuesta, pero el servidor
      >   responde antes de que llegue la captura siguiente, así que la observación NO es
      >   concluyente. No se cambia el rol sin haber visto el fallo. *(Superado: el owner lo
      >   quitó después por precaución, `.tint(.red)` en su lugar — ver «Revisión», ronda 1,
      >   nota 1.)*
      > - VoiceOver/Accessibility Inspector: `inspect` del simulador no disponible; lo
      >   comprobó el owner a mano el 2026-09-15: la fila se ajusta (sube y baja la
      >   cantidad), en 1 no baja, y «Quitar» sale UNA sola vez en el rotor — el riesgo del
      >   doble «Quitar» de `design.md` no se da, así que no se quita ninguna.
      >   Esa comprobación se hizo con `role: .destructive`; el owner la REPITIÓ con el código
      >   final (sin rol, `.tint(.red)`) el mismo día: «Quitar» sigue saliendo una sola vez.

## 6. Composición y cierre

- [x] 6.1 Mutación sobre el composition root: borrar el `register` de `CartUpdateServicing`
      en `CartModule`, comprobar que `AppTests/CompositionRootTests.swift` se pone rojo, y
      restaurarlo. Verificación: `xcodebuild test … -only-testing:AppTests` en rojo con la
      mutación y en verde sin ella.

      > Hecho el 2026-09-15 (iPhone 17). Con el `register` borrado, «Every module resolves its
      > ViewModel without crashing» revienta con `Fatal error: Dependency
      > 'CartFeature.CartUpdateServicing' not registered`; restaurado, pasa. `CartModule` quedó
      > idéntico al original.
- [x] 6.2 Editar el `Purpose` de `openspec/specs/carrito/spec.md`: fuera «Solo lectura —
      modificar el carrito no es de esta capacidad.». Pasa a decir que la capacidad lee el
      carrito y edita cantidades y líneas, y que las ediciones no persisten en el servidor.
      Verificación: `grep -c "Solo lectura" openspec/specs/carrito/spec.md` devuelve `0`.
- [x] 6.3 Repasar uno a uno los criterios de aceptación de `proposal.md` y marcarlos.
      Verificación: ninguna casilla queda sin marcar sin una nota que diga por qué.

      > Los 15 marcados. El 12 (VoiceOver) por la comprobación manual del owner en la 5.4; el
      > 15 por la 6.4.
- [x] 6.4 `/kit-verifica` en verde.

      > 2026-09-15: Platform build/tests, Features build/tests y App build + AppTests +
      > AppSnapshotTests en verde; sin lógica repetida en lo que toca el cambio (los 2 grupos
      > preexistentes de la 2.2). Firmado contra el árbol. OJO al commitear: la huella es
      > `git diff HEAD` + índice, así que los ficheros NUEVOS (`CartUpdateService.swift`,
      > `CartUpdateServiceTests.swift`) y esta carpeta no entran en ella hasta stagearlos —
      > stagear, `/kit-verifica` y commitear, en comandos separados.

## Revisión

- Ronda 1 del revisor (2026-09-15): **GREEN**, sin bloqueantes. Tres notas; ninguna se aplicó en
  código en esa ronda (la 1 se aplicó después, por decisión del owner):
  1. *Sospecha sin reproducir:* con `role: .destructive`, si el `PUT` de «Quitar» FALLA, SwiftUI
     podría haber animado la fila fuera y no devolverla (cláusulas 5 y 7). La 5.4 solo lo vio con
     éxito. **Decidido por el owner el 2026-09-15, sin reproducirlo:** fuera el rol, `.tint(.red)`
     (la salida que ya preveía `design.md`, enmendado). Cambia código: vuelven `/kit-verifica` y
     el revisor sobre la rodaja nueva.
  2. `notFoundSurfaces` también pasaría si el request no casara con el intercambio registrado;
     no deja hueco porque método y ruta los fija `putsToTheCartPath`. Sin cambio.
  3. Al commitear, los dos ficheros nuevos van en el mismo commit (sin ellos no compila) y hay
     que stagear antes de volver a `/kit-verifica` — ya anotado en la 6.4.
- La rodaja traía además ~60 ficheros de cinco commits previos (`3cd4ba4..77e9bf5`) que nunca se
  marcaron; el revisor no los miró, pero sus cambios archivados registran su propia ronda de
  revisor. Punto marcado con `rodaja.sh --revisada`.
- Tras quitar el rol (2026-09-15): `/kit-verifica` otra vez en verde, firmado. En el simulador
  (iPhone 17, DummyJSON real, sesión iniciada por el owner): al deslizar, «Quitar» sale en ROJO
  igual que antes; pulsarlo quita Baseball Ball (`10 artículos`, `US$11,493.00`), y el
  deslizamiento completo sigue disparando la acción y quita iPhone 6 (`7 artículos`,
  `US$10,653.00`) sin deshacer la anterior. El caso del `PUT` que falla sigue sin reproducirse:
  el cambio lo evita por construcción, no por haberlo visto.
- Ronda 2 del revisor (2026-09-15), sobre la rodaja del cambio de rol: **GREEN**. Ejecutó una app
  de prueba aparte (iOS 26.5 en otro simulador; no hay runtime de iOS 17): sin rol, el
  deslizamiento completo sigue disparando la acción, `.tint(.red)` pinta el botón igual, y la
  acción «Quitar» de la fila no depende del rol. **Sin comprobar:** el rotor de VoiceOver con el
  código nuevo —la comprobación del owner de la 5.4 fue con `.destructive`—; lo peor posible es
  un «Quitar» duplicado, riesgo ya previsto en `design.md`. *(Comprobado después por el owner con
  el código final: un solo «Quitar» — ver la nota de la 5.4.)* La nota de la 5.4 que decía «no se
  cambia el rol» remite ahora a la decisión. Punto marcado de nuevo con `rodaja.sh --revisada`.

## Mutaciones (criterio 13)

Resultados de lo ejecutado el 2026-09-15, que las tareas solo recogían como instrucción. Cada
tanda: copia del fichero, mutaciones marcadas `/*MUT*/` y CONTADAS antes de correr (un marcador
de menos invalida la tanda), `swift test`, y restauración comprobada con `cmp`.

- **1.2** — `id: dto.id` → `nil` en `CartService`: rojos `decodesLines` y
  `decodesTotalFromActualJSON`.
- **2.3** — tanda A (`merge: true`, ruta fija `/carts/1`, `discountedPrice` → `total`): rojos el
  cuerpo, el `PUT` (en `cartId: 42`) y el mapeo; verdes vacío y 404. Tanda B (`id: nil`, líneas
  invertidas): rojos vacío, mapeo y cuerpo (orden). Tanda C (`HTTPMethod.post`, error tragado):
  rojos `PUT` (`"POST" == "PUT"`) y 404 (no lanza). Los cinco tests, rojos con su mutación.
- **3.2** — Logic 1 (solo la línea cambiada, sin guardia `< 1`, sin filtro al quitar, sin guardia
  de `id`, `removeLine` sin traducir): rojos lista completa, `< 1`, quitar, segunda edición, sin
  `id` y traducción de quitar; verdes los de carga y los cinco de traducción de `setQuantity`.
  *El primer intento de esta tanda no se aplicó —el `perl` falló y los marcadores dieron 0 de
  5—; se descartó y se repitió.* Logic 2 (devolver el carrito de entrada, `setQuantity` sin
  traducir): rojos lista completa, segunda edición y los cinco de traducción.
- **4.2/4.3** — VM A (sin guardia, sin `setEmpty`, sin asignar `cart`, sin `stopActivity` en la
  cancelación): rojos «otra no llega a la Logic», vacío, «enseña la respuesta», «después de un
  fallo» y cancelación de red. VM B (`stopActivity` sin `!Task.isCancelled`, `.silent`): rojos
  pantalla retirada y banner. VM C (`cart` asignado ANTES de llamar a la Logic): rojo «nada cambia
  antes de la respuesta» en su aserción de antes (`CartViewModelTests.swift:152`), que VM A solo
  tumbaba por la aserción final.
- **6.1** — anotada en su tarea.

- Ronda 1 del juez: ACEPTADO · comportamiento: no
