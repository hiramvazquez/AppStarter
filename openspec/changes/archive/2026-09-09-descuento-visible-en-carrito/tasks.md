## 1. El dato entra: del DTO al modelo

- [x] 1.1 Añadir `total: Double` a `GetUserCartsRequest.LineDTO` y a `.CartDTO`
      (`Packages/Features/Sources/CartFeature/Services/CartService.swift`), no opcional —
      igual que sus hermanos `price`/`quantity`/`discountedTotal`, por lo que razona
      `design.md` § Risks. Verificación: `cd Packages/Features && swift build` compila
      (los tests aún no, porque sus stubs de DTO no tienen el campo).
- [x] 1.2 Añadir `public let total: Double` a `CartLine` y a `Cart`
      (`CartFeature/CartLogic.swift`), con el comentario de por qué se decodifica en vez de
      multiplicar/sumar (la regla que `Cart.discountedTotal` ya documenta). Verificación:
      `swift build` de `Packages/Features` compila.
- [x] 1.3 Mapear `dto.total` en `CartService.fetchCarts`, en la línea y en el carrito, y
      poner `total: 0` en `Cart.empty`. Verificación: `swift build` en verde.
- [x] 1.4 Añadir `discountAmount` (`total - discountedTotal`, en crudo) y `hasDiscount`
      (comparación en **céntimos redondeados**, `design.md` § Decisions) a `CartLine` y a
      `Cart`. Verificación: `swift build` en verde.

## 2. Los tests del dato

- [x] 2.1 Actualizar `CartLine.fixture` (`CartFeatureTests/CartModelTests.swift`) con
      `total: Double = 119.96`, y los stubs de DTO de
      `CartFeatureTests/Services/CartServiceTests.swift` con su `total`. Verificación:
      `cd Packages/Features && swift test` vuelve a compilar y los 23 tests siguen verdes.
- [x] 2.2 En `CartServiceTests.decodesLines`, asertar `line.total == 119.96` y
      `carts.first?.total == 119.96` — el mapeo del campo nuevo, en los dos niveles. Sin
      esto se puede poner a cero y nada se entera, que es el fallo que el revisor por
      mutación ya cazó una vez en este mismo test.
- [x] 2.3 Tests en `CartModelTests` para `discountAmount` (`119.96 / 105.41` → `14.55` con
      tolerancia de céntimo) y para `discountAmount == 0` cuando los dos importes son el
      mismo valor. Ojo: `discountAmount` va en crudo, así que no es `0` para una diferencia
      por debajo del céntimo — quien decide eso es `hasDiscount`, y es la 2.4.
- [x] 2.4 Tres tests en `CartModelTests` sobre la frontera de `hasDiscount`, que es lo que
      la cláusula 3 del requisito mide: `false` con importes idénticos, `false` con una
      diferencia **por debajo** del céntimo (`119.96` / `119.9601` — el caso que la
      igualdad exacta sobre `Double` pintaría como un tachado idéntico al importe de al
      lado y un «Descuento −0,00 $»), y `true` con una diferencia de **un céntimo entero**
      (`119.96` / `119.95`), que sí es una rebaja y tiene que verse.

## 3. Los textos de accesibilidad

- [x] 3.1 Crear `Packages/Features/Sources/CartFeature/CartCopy.swift` con
      `lineAccessibilityLabel(_ line: CartLine) -> String` y
      `totalAccessibilityLabel(_ cart: Cart) -> String`, funciones puras, **sin**
      `import SwiftUI` ni `UIKit`. Verificación: `grep -c "import SwiftUI\|import UIKit"
      Packages/Features/Sources/CartFeature/CartCopy.swift` devuelve `0`.
- [x] 3.2 Crear `CartFeatureTests/CartCopyTests.swift` con cuatro tests sobre el string
      devuelto: línea con descuento (nombra unitario, importe anterior e importe que se
      paga), línea sin descuento (no nombra ningún importe anterior), pie con descuento
      (nombra subtotal, descuento y total) y pie sin descuento (solo el total).
      Verificación: `swift test` en verde.

## 4. La pantalla

- [x] 4.1 En `CartLineRow` (`CartFeature/CartView.swift`), mostrar `line.total` tachado
      antes de `line.discountedTotal` **solo si `line.hasDiscount`**, y pasar
      `CartCopy.lineAccessibilityLabel(line)` a `.accessibilityLabel(...)` sobre el
      `.accessibilityElement(children: .combine)` que ya está. Verificación: `swift build`
      de `Packages/Features` en verde.
- [x] 4.2 En `CartTotalFooter`, sustituir la fila única por unidades + `Subtotal` /
      `Descuento` / `Total` cuando `cart.hasDiscount`, y dejar la fila de hoy cuando no.
      Poner `CartCopy.totalAccessibilityLabel(cart)` como `.accessibilityLabel`.
      Verificación: `swift build` en verde.
- [x] 4.3 Actualizar el `Cart` del `#Preview` (`CartPreviewLogic`) con
      `total: 119.96` en la línea y en el carrito, para que la preview enseñe el caso que
      motivó el cambio. Verificación: `swift build` en verde.

## 5. Las fotos

- [x] 5.1 En `AppSnapshotTests/CartSnapshotTests.swift`, añadir el `total` a los dos
      `CartLine` y al `Cart` del `StubLogic` (`.content`): `1620.00`/`1481.20` y
      `1999.99`/`1798.99`, con `total` de carrito `3619.99`. Verificación:
      `xcodebuild test-without-building … -only-testing:AppSnapshotTests` compila.
- [x] 5.2 Añadir un `StubOutcome` nuevo, `.sinDescuento`, con un carrito cuyo `total` es
      igual a su `discountedTotal` en las dos líneas y en el carrito, y un
      `testContentSinDescuentoKit` que lo fotografíe (un solo tema, por la razón que el
      propio fichero documenta para `.content`).
- [x] 5.3 Regrabar `testContentKit.kit.png` y grabar la referencia nueva.
- [x] 5.4 **Abrir las dos imágenes y mirarlas.** En `testContentKit.kit.png` tiene que
      verse, en cada línea, el importe tachado junto al que se paga, y en el pie las tres
      filas del desglose; en la nueva, ni un tachado ni una fila de «Descuento». Un
      snapshot recién grabado está verde diga lo que diga la imagen — así llegó esta
      pantalla a decir «4 artículo». Verificación: describir en el commit qué se ve en cada
      una.
- [x] 5.5 Con la imagen delante, decidir si el desglose se queda en el `footer` de la
      `Section` o se mueve a su propia `Section` (`design.md` § Decisions lo deja
      explícitamente abierto a esto). Si se mueve, regrabar las dos referencias y volver a
      mirarlas.

## 6. Cierre

- [x] 6.1 Repasar los criterios de aceptación de `proposal.md` uno a uno y marcarlos.
- [x] 6.2 `/kit-verifica` en verde y firmado contra el diff staged.
