# Cambiar la cantidad de una línea del carrito y quitarla

## Why

La pantalla de carrito enseña qué lleva y cuánto se paga, pero no deja tocar nada: la spec
`carrito` la declara de solo lectura. Quien ve cuatro unidades de algo que quería dos, o un
producto que ya no quiere, no tiene nada que hacer ahí. DummyJSON expone `PUT /carts/{id}`
para eso, y la pantalla ya tiene el resto —líneas, totales, rebaja, estados—.

Medido contra el servidor real el 2026-09-15, con
`curl -X PUT https://dummyjson.com/carts/1 -d '{"merge":false,"products":[…]}'` seguido de
`curl https://dummyjson.com/carts/user/1`. Tres hechos condicionan el acuerdo:

- **No persiste.** Después del `PUT`, el `GET` vuelve a traer el carrito original (Blue Frock
  con 4 unidades y `totalQuantity` 12).
- **Quitar no es poner la cantidad a 0.** Con `quantity: 0` la línea se queda en el carrito,
  a cero: la API no valida que la cantidad sea positiva (código de DummyJSON en `master`,
  `src/controllers/cart.js`). Una línea se quita mandando la lista sin ella, con
  `merge: false`.
- **La respuesta no tiene la forma del `GET`.** Cada línea trae `discountedPrice` redondeado
  a entero (`53`, `10548`, `840`) donde el `GET` trae `discountedTotal` con céntimos
  (`10547.97`, `839.76`).

## What Changes

- `Cart` gana el `id` del carrito. `GET /carts/user/{id}` ya lo manda y hoy se descarta al
  decodificar, y sin él no hay a qué carrito mandar el `PUT`.
- Nace `CartUpdateService` (`CartFeature/Services/CartUpdateService.swift`), con su
  `UpdateCartRequest` (`PUT /carts/{id}`) y un DTO propio, porque el wire no coincide con el
  del `GET`. Es un servicio aparte y no un método más de `CartService`: una llamada a API es
  un Service (`AGENTS.md`).
- `CartLogic` aprende a cambiar la cantidad de una línea y a quitarla. Cada edición manda
  **la lista completa** de líneas que deben quedar, con `merge: false` explícito. Como el
  servidor no guarda nada, es la única forma de que una segunda edición no deshaga la
  primera.
- `CartViewModel` gana dos acciones, que corren como actividad secundaria: el carrito sigue
  a la vista y la pantalla no acepta otra edición hasta que el servidor responde. Con éxito,
  la respuesta sustituye al carrito. Si la edición falla, el carrito se queda como estaba y
  un banner lo dice. Quitar la última línea lleva al estado vacío.
- `CartView`: cada línea gana un control de cantidad (mínimo 1) y una acción de deslizar
  «Quitar». Las dos se pueden usar con VoiceOver.
- `CartModule` registra `CartUpdateServicing`.

Dos decisiones del owner, tomadas el 2026-09-15 a la vista de las mediciones:

- **La respuesta sustituye al carrito entero.** Tras la primera edición, también las líneas
  que no se tocaron pasan a céntimos redondeados (`10.547,97 $` → `10.548,00 $`). Las líneas
  y el pie cuadran porque salen de la misma respuesta.
- **Al salir y volver a entrar, reaparece el carrito original.** Es un límite de DummyJSON y
  la spec lo declara como tal: la pantalla no promete persistencia.

No es **BREAKING** fuera de la feature: ninguna otra puede importar `Cart` (R13), y
`App/RootView.swift` construye la pantalla por su factoría, cuya firma no cambia.

## Capabilities

### New Capabilities

Ninguna.

### Modified Capabilities

- `carrito`: deja de ser de solo lectura. Se añade un requisito para la edición: cambiar la
  cantidad, quitar, qué se ve tras la respuesta, y qué pasa si falla, si se cancela o si se
  intenta otra en vuelo. También declara el límite de persistencia. Los dos requisitos
  vigentes no cambian de texto: la edición tiene que cumplirlos, incluida la rebaja medida
  sobre lo que dice la API. El `Purpose` de `openspec/specs/carrito/spec.md` dice «Solo
  lectura» y un delta no lo toca, así que se edita a mano.

## Fuera de alcance

- **Añadir productos** (`POST /carts/add`), **borrar el carrito entero**
  (`DELETE /carts/{id}`) y vaciarlo de un golpe.
- **Persistir las ediciones**, en local o reenviándolas al volver: se declara el límite.
- **Un tope de unidades por stock.** La respuesta del carrito no trae stock y la API no
  valida máximos. El único límite es el mínimo de 1.
- **Edición optimista**, que cambiaría la pantalla antes de que responda el servidor. Ver
  `design.md`.
- **Deshacer** una línea quitada.
- **Recalcular importes en la app** y decodificar `discountPercentage`: siguen fuera por lo
  que ya fija la spec `carrito`.
- **La moneda escrita a mano** (`code: "USD"`): es un problema anterior y es otro cambio.
- **Abrir el carrito desde otro sitio que no sea `Profile`**, y el deep link.
- **`AppUITests`**: quedan fuera de la firma por lo que declara `kit.conf`.

## Criterios de aceptación

- [x] `GetUserCartsRequest` decodifica el `id` de cada carrito y `CartService` lo lleva a
      `Cart.id`. Lo fija un test que pasa bytes reales de `GET /carts/user/1` por
      `InMemoryTransport`.

      *Precisado el 2026-09-15, a raíz del juez: los «bytes reales» son un RECORTE de la
      respuesta real —un carrito con una de sus cuatro líneas, en el test que ya existía en
      `CartServiceTests`—, no la respuesta completa. Lo que el criterio existe para fijar, la
      clave `id` del wire pasando por `JSONDecoder`, queda fijado igual; el texto decía de más.*
- [x] `UpdateCartRequest` es `PUT /carts/{id}` y su cuerpo codificado lleva `"merge": false`
      y las líneas en el orden del carrito. Un test fija el método, la ruta y el cuerpo.
- [x] `CartUpdateService` decodifica la respuesta real medida el 2026-09-15, con
      `discountedPrice`, y la lleva a `CartLine.discountedTotal`. El test pasa esos bytes por
      `InMemoryTransport`, no un `Response` construido en Swift.
- [x] `CartLogic` cambia una cantidad mandando la lista completa con esa línea cambiada, y
      quita una línea mandando la lista sin ella. Los tests miran lo que recibe el mock del
      servicio, e incluyen una segunda edición sobre el resultado de la primera que conserva
      las dos.
- [x] `CartLogic` no llama al servicio con una cantidad menor que 1. Test.
- [x] `CartLogic` traduce el fallo del `PUT` a `CartError`: sin conexión → `offline`,
      404 → `notFound`, 503 → `server`, cancelación → `cancelled`, el resto → `unknown`. Un
      test por caso.
- [x] Tras una edición con éxito, `CartViewModel.cart` es exactamente el que devolvió la
      `Logic`. Quitar la última línea deja la fase en `.empty`. Una edición que falla deja
      `cart` como estaba, la fase en `.content`, la actividad parada y un banner puesto. Un
      test por caso.
- [x] `CartViewModel` no acepta una edición mientras otra está en vuelo: la `Logic` recibe
      una sola llamada. Test.
- [x] Una cancelación de red durante una edición no presenta error ni deja la actividad en
      vuelo. Si la `Task` de la edición ya estaba cancelada, la actividad no se toca. Los dos
      tests van en la suite `.serialized` de cancelación de `CartViewModelTests`.
- [x] Si se borra el `register` de `CartUpdateServicing` en `CartModule`,
      `AppTests/CompositionRootTests.swift` se pone rojo. Verificado por mutación.
- [x] `testContentKit` y `testContentSinDescuentoKit` se regraban. Abiertas, las dos imágenes
      enseñan el control de cantidad en cada línea sin importes ni títulos partidos.
- [x] En el simulador, con VoiceOver o el Accessibility Inspector, se puede subir y bajar la
      cantidad de una línea y quitarla sin salir de la fila. El commit describe lo que se oyó.
- [x] Ningún test nuevo pasa con revertido el código que dice cubrir. Verificado por
      mutación, test por test.
- [x] El `Purpose` de `openspec/specs/carrito/spec.md` ya no dice «Solo lectura».
- [x] `/kit-verifica` en verde.

## Impact

Código de producto (`Packages/Features/Sources/CartFeature/`):

| Fichero | Qué cambia |
|---|---|
| `CartLogic.swift` | `Cart.id`; `CartLogicProtocol`/`CartLogic` ganan las dos ediciones, y el `init` recibe `any CartUpdateServicing` |
| `Services/CartService.swift` | `CartDTO.id` y su mapeo |
| `Services/CartUpdateService.swift` | **nuevo**: `UpdateCartRequest`, su DTO, `CartUpdateServicing` y `CartUpdateService` |
| `CartViewModel.swift` | acciones de cambiar cantidad y quitar |
| `CartView.swift` | control de cantidad, acción «Quitar», acciones de accesibilidad y la `CartPreviewLogic` |
| `CartModule.swift` | registro de `CartUpdateServicing` y el `init` nuevo de `CartLogic` |

Tests:

| Fichero | Qué cambia |
|---|---|
| `CartFeatureTests/Services/CartUpdateServiceTests.swift` | **nuevo** |
| `CartFeatureTests/Services/CartServiceTests.swift` | el `id`, en el stub y en los bytes reales |
| `CartFeatureTests/CartLogicTests.swift` | las ediciones, sus errores y el `init` nuevo |
| `CartFeatureTests/CartViewModelTests.swift` | las ediciones, el bloqueo y la cancelación |
| `CartFeatureTests/Mocks/CartMocks.swift` | los mocks ganan las ediciones; nace el del servicio de edición |
| `CartFeatureTests/CartModelTests.swift`, `CartCopyTests.swift` | sus `Cart(...)` nombran el `id` |
| `AppSnapshotTests/CartSnapshotTests.swift` | el `StubLogic` implementa las ediciones y nombra el `id` |
| `AppSnapshotTests/__Snapshots__/CartSnapshotTests/` | se regraban las dos referencias de contenido |

Spec: `openspec/specs/carrito/spec.md`, el `Purpose`, a mano.

Sin cambios: `CartError` (el `PUT` falla de las mismas cinco formas),
`App/AppCancellationRecognizer.swift` (`CartError.cancelled` ya está registrado),
`AppRoute`, `App/RootView.swift`, `App/AppModule.swift` y `AppTests/CompositionRootTests.swift`,
que ya resuelve la factoría de punta a punta.
