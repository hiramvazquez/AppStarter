## Why

La pantalla de carrito enseña dos números que no cuadran y no explica por qué. En la línea
de "Blue Frock", a la izquierda pone `4 × 29,99 $` y a la derecha `105,41 $`; la
multiplicación da `119,96 $`. La diferencia son `14,55 $` de descuento que la pantalla no
menciona **en ninguna parte** — ni en la línea, ni en el pie. Quien mira eso no ve un
descuento: ve una cuenta mal hecha, o un precio que no es el que creía.

La causa está en el borde de red, no en la vista: `GetUserCartsRequest` descarta los campos
que la API sí manda. Medido contra el endpoint real el 2026-09-09 con
`curl -s https://dummyjson.com/carts/user/1`:

```json
{"id":162,"title":"Blue Frock","price":29.99,"quantity":4,
 "total":119.96,"discountPercentage":12.13,"discountedTotal":105.41}
```

y a nivel de carrito, `"total":13037.88,"discountedTotal":11510.81`. El importe sin
descuento existe, viene del servidor y hoy se tira en la decodificación: `LineDTO` solo lee
`price`, `quantity`, `discountedTotal` y `thumbnail`, y `CartDTO` solo `discountedTotal` y
`totalQuantity`. Sin ese dato, `CartLine` no puede decir de dónde sale la rebaja, y la vista
tampoco.

## What Changes

- `CartLine` y `Cart` (`CartFeature/CartLogic.swift`) ganan el importe **sin** descuento
  (`total`), que hoy no existe en el modelo, y de él derivan `discountAmount` y
  `hasDiscount`. No se recalcula multiplicando ni sumando: se decodifica, igual que
  `discountedTotal`, por la razón que ya fija la spec `carrito` — si la API y la
  aritmética discreparan, manda la API, que es quien cobra.
- `GetUserCartsRequest.LineDTO` y `.CartDTO` (`CartFeature/Services/CartService.swift`)
  decodifican `total`, y `CartService.fetchCarts` lo mapea al modelo.
- `CartLineRow` (`CartFeature/CartView.swift`) muestra el importe sin descuento tachado
  junto al que se paga, **solo cuando hay descuento**.
- `CartTotalFooter` (`CartFeature/CartView.swift`) pasa de una cifra a un desglose
  `Subtotal → Descuento → Total`, también **solo cuando hay descuento**; sin descuento se
  queda como está hoy, en una línea.
- La línea y el pie ganan `accessibilityLabel` explícito. Un tachado no lo lee VoiceOver:
  con `.accessibilityElement(children: .combine)` y tres cifras en la fila, hoy diría
  «Blue Frock, 4 × 29,99 $, 119,96 $, 105,41 $» — tres números sin relación, que es peor
  que la fila de dos que había antes del cambio. El texto compuesto vive en un
  `CartCopy.swift` nuevo, sin `import SwiftUI`, para que se pueda fijar con un test en vez
  de con un UI test (que la firma de `/kit-verifica` no cubre, por decisión declarada en
  `kit.conf`).
- No es **BREAKING** para nadie fuera de la feature: `Cart`/`CartLine` son `public` pero
  ninguna otra feature puede importarlas (R13), y `App/RootView.swift` solo construye la
  vista por su factoría.

## Capabilities

### New Capabilities

Ninguna.

### Modified Capabilities

- `carrito`: la cláusula 1 del requisito hoy pide «cantidad y su total con descuento». Eso
  es exactamente lo que la pantalla hace y aun así los números no cuadran, porque el
  requisito no exige que la rebaja sea **legible**. Pasa a exigir que la cifra que se paga
  se pueda reconciliar con la que se ve al lado. Y se añade un requisito propio para la
  rebaja —cuándo se ve, cuándo NO debe verse porque vale cero, de dónde sale el importe
  anterior y qué oye un lector de pantalla—, que es una preocupación distinta de los
  estados de la pantalla y no cabe como una cláusula más del requisito que ya había.

## Fuera de alcance

- **Modificar el carrito** — cantidades, quitar líneas, vaciar. La capacidad `carrito` es
  de solo lectura y sigue siéndolo.
- **`discountPercentage`.** La API lo manda por línea (`12.13`) y no se decodifica: el
  diseño acordado enseña el importe, no el porcentaje. Meterlo en el modelo sería
  superficie para nadie, que es justo lo que `CartLine` documenta que no hace.
- **La moneda.** `CartView` formatea con `code: "USD"` a pelo hoy y lo seguirá haciendo. Es
  un problema real y distinto; arreglarlo aquí mezclaría dos cambios.
- **El resto de pantallas.** Este cambio no toca ninguna otra feature ni afirma nada sobre
  ellas.
- **`AppUITests`.** Nada de lo de aquí se verifica ahí, por lo que declara `kit.conf`.

## Criterios de aceptación

- [x] `GetUserCartsRequest.LineDTO` y `.CartDTO` tienen un campo `total`, y
      `CartServiceTests` fija que un 200 con `"total": 119.96` produce un `CartLine.total`
      de `119.96` y un `Cart.total` de `119.96`.
- [x] `CartLine.discountAmount` devuelve `14.55` (con tolerancia de céntimo) para la línea
      `total: 119.96 / discountedTotal: 105.41`, y `0` cuando los dos importes son el
      mismo valor — con un test por caso en `CartModelTests`.
- [x] `CartLine.hasDiscount` y `Cart.hasDiscount` son `false` cuando los dos importes
      coinciden **redondeados a céntimos** —incluida una diferencia por debajo del
      céntimo— y `true` con una diferencia de un céntimo entero. Un test por cada uno de
      los tres casos: es la frontera, y la que no se prueba es la que se rompe.
- [x] `CartLine.hasDiscount` y `Cart.hasDiscount` son `false` cuando el importe con
      descuento es **mayor** que el importe sin descuento —un recargo no es una rebaja y no
      se decora como tal— y también cuando el importe no cabe en un `Decimal`. Un test por
      caso en `CartModelTests`.
- [x] `CartCopy.lineAccessibilityLabel(_:)` nombra las tres cifras de una línea con
      descuento (unitario, antes, después) y omite la de «antes» cuando no lo hay; dos
      tests en `CartFeatureTests` lo fijan sobre el string devuelto.
- [x] `CartCopy.totalAccessibilityLabel(_:)` nombra subtotal, descuento y total cuando hay
      descuento, y solo el total cuando no; dos tests.
- [x] El snapshot `testContentKit` de `AppSnapshotTests/CartSnapshotTests.swift` se regraba
      y en la imagen se ve, en cada línea con descuento, el importe tachado junto al que se
      paga, y en el pie las tres filas del desglose.
- [x] Hay un snapshot nuevo de un carrito **sin** descuento (sus dos importes son el mismo) en
      el que no aparece ni tachado ni fila de «Descuento»: la pantalla no gana ruido cuando
      no hay nada que explicar.
- [x] `CartCopy.swift` no importa `SwiftUI` ni `UIKit`.
- [x] `/kit-verifica` en verde y firmado contra el diff staged.

## Impact

Código de producto (`Packages/Features/Sources/CartFeature/`):

| Fichero | Qué cambia |
|---|---|
| `CartLogic.swift` | `CartLine.total`, `Cart.total`, `discountAmount`, `hasDiscount`, y `differsInCents` — la frontera en céntimos, escrita una sola vez para los dos tipos |
| `Services/CartService.swift` | `LineDTO.total`, `CartDTO.total`, y su mapeo |
| `CartView.swift` | `CartLineRow`, `CartTotalFooter`, y el `Cart` del `#Preview` |
| `CartCopy.swift` | **nuevo** — los textos de accesibilidad, sin SwiftUI |

Tests:

| Fichero | Qué cambia |
|---|---|
| `CartFeatureTests/CartModelTests.swift` | `CartLine.fixture` gana `total`; tests de `discountAmount`/`hasDiscount` |
| `CartFeatureTests/Services/CartServiceTests.swift` | los stubs de DTO ganan `total`; aserciones sobre él, y un test que decodifica JSON de verdad con `InMemoryTransport` |
| `CartFeatureTests/CartCopyTests.swift` | **nuevo** — los cuatro tests de accesibilidad |
| `CartFeatureTests/CartLogicTests.swift` | su constructor `Cart(...)` de conveniencia gana `total` |
| `CartFeatureTests/CartViewModelTests.swift` | ídem, en sus dos constructores |
| `AppSnapshotTests/CartSnapshotTests.swift` | el `StubLogic` construye `Cart` con `total`; test nuevo sin descuento |
| `AppSnapshotTests/__Snapshots__/CartSnapshotTests/` | `testContentKit.kit.png` regrabada, más la referencia nueva |

Sin cambios: `CartViewModel`, `CartLogic.load`, `CartError`, `CartModule`, `AppRoute`,
`App/RootView.swift`, `App/AppModule.swift`, y la red (mismo endpoint, misma petición —
solo se decodifican campos que ya venían en la respuesta).

Ojo con leer esa lista de más: el CÓDIGO de `CartViewModel` y `CartLogic` no se toca, pero
sus tests sí aparecen arriba. `Cart` gana un campo obligatorio, así que todo constructor
`Cart(...)` del repo tiene que nombrarlo — incluidos los helpers de dos suites que no
prueban nada del descuento. Es el precio de que el campo NO sea opcional, que es la decisión
que razona `design.md` § Risks.
