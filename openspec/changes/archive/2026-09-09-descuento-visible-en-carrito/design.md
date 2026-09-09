## Context

Ver `proposal.md` § Why para el motivo. Lo que condiciona el cómo:

- El dato que falta **existe en la respuesta** y se está descartando en la decodificación
  (`GetUserCartsRequest.LineDTO` / `.CartDTO`). No hay petición nueva, ni endpoint nuevo, ni
  campo que negociar con nadie: es ensanchar dos structs `Decodable`.
- `Cart`/`CartLine` viven en `CartFeature`, no en `Domain`, y ninguna otra feature puede
  importarlas (R13). Ensanchar el modelo no tiene radio fuera de esta pantalla.
- El pie y la fila se fotografían: `AppSnapshotTests/CartSnapshotTests.swift` graba
  `testContentKit` sobre `CartView` entera. Un snapshot recién grabado **siempre** sale
  verde — es exactamente cómo esta pantalla llegó a decir «4 artículo» con los tests en
  verde. Lo que asegura el cambio es mirar el PNG, no que el test pase.
- `AppUITests` queda fuera de la firma de `/kit-verifica` por decisión declarada en
  `kit.conf`. Cualquier cosa que solo se pueda comprobar ahí, no se comprueba.

## Goals / Non-Goals

**Goals:**

- Que el importe sin descuento entre en el modelo por la puerta de la API, no por
  aritmética local.
- Que la pantalla distinga «hay rebaja» de «no hay rebaja» sin que la segunda pague ruido.
- Que lo que el tachado dice visualmente se pueda **fijar con un test normal**, no con un UI
  test que nadie corre.

**Non-Goals:**

- Cambiar el modelo de dinero. Sigue siendo `Double`, con los problemas que eso tiene; este
  cambio no los arregla ni los empeora.
- Tocar `CartViewModel`, `CartLogic.load`, `CartError` ni el `CartModule`. La rebaja no es
  una fase ni un error: es un dato que ya venía y una vista que no lo pintaba.

## Decisions

### El importe sin descuento se decodifica; no se multiplica

`CartLine.total` sale de `LineDTO.total`, y `Cart.total` de `CartDTO.total`.

*Alternativa descartada:* calcularlo como `Double(quantity) * unitPrice` y ahorrarse tocar
los DTO. Es más código nuevo (una regla de negocio inventada) que el campo que ya viene, y
falla en el caso que importa: si el servidor aplicara la rebaja de otra forma, la pantalla
enseñaría un «antes» que nadie ha cobrado nunca. `Cart` ya documenta la regla para el total
con descuento —«manda la API, que es quien cobra»— y esto es la misma regla aplicada al otro
extremo de la resta. Medido el 2026-09-09, la API es consistente
(`29.99 × 4 = 119.96 = total`), pero el requisito no depende de que lo siga siendo.

*Alternativa descartada:* decodificar también `discountPercentage`. El diseño acordado
enseña el importe, no el porcentaje; el campo se quedaría en el modelo sin consumidor, que
es justo lo que `CartLine` documenta que no hace. Si algún día se enseña el «−12%», es
decodificarlo entonces.

### `discountAmount` y `hasDiscount` son derivados, no campos

`discountAmount` es `total - discountedTotal`, y `hasDiscount` la comparación de los dos.
No se guardan: dos campos que siempre son función de otros dos se pueden desincronizar, y no
hay nada que sincronizar si no existen.

**La comparación se hace en céntimos redondeados**, no con `==` sobre `Double` — y eso lo
dice ahora la propia cláusula 3 del requisito, no solo este documento. No es un tecnicismo
que se pueda dejar aquí abajo: si la spec pidiera coincidencia exacta y el código comparase
céntimos, un importe de `119.9601` frente a `119.96` los pondría a discrepar, y el acuerdo
manda contra el código. Escrito en los dos sitios, la frontera es una sola:

```swift
var hasDiscount: Bool { centsOnScreen(discountedTotal) < centsOnScreen(total) }
```

Esa forma es la SEGUNDA. La primera fue
`(total * 100).rounded() != (discountedTotal * 100).rounded()`, y la revisión la tumbó por
dos motivos distintos, los dos medidos:

- **`!=` es simétrico y «rebaja» no lo es.** Con `discountedTotal` mayor que `total` —un
  recargo— la fila tachaba el importe menor encima del mayor y el pie escribía
  `Descuento −-US$5.00`, con el signo del formateador pegado al nuestro. Ahora es `<`, y la
  spec lo recoge en su cláusula 4: un recargo no se decora.
- **`× 100` en binario mete el error ANTES de redondear.** `1620.125` y `1620.12` se pintan
  los dos como `US$1,620.12`, y el predicado los daba por distintos: la fila tachaba un
  importe idéntico al de abajo, que es la cláusula 3 incumplida por el mismo desajuste de
  redondeo que la frontera existía para evitar. `centsOnScreen` redondea sobre la
  representación decimal corta del doble y con half-even, que es lo que hace `.currency(...)`.
  Contrastado con el string del formateador sobre 240 000 pares: 1 desacuerdo, y es
  `US$0.00` contra `-US$0.00`. `.rounded(.toNearestOrEven)` a secas NO bastaba — se quedaba
  en 1192 desacuerdos, porque el problema no es solo la regla, es cuándo se pasa a decimal.

Y `centsOnScreen` devuelve `Decimal?`, no `Decimal`. La primera versión caía a
`?? Decimal(amount)` cuando `Decimal(string:)` no podía parsear —desde ~`1e128`, y
`JSONDecoder` acepta hasta `1e400`—, y ese fallback no protegía de nada: producía NaN, y
`NaN < finito` es `true` en `Decimal`, al revés que en IEEE. Es decir, resucitaba exactamente
el recargo-pintado-como-rebaja que el `<` acababa de cerrar, con su doble signo en el pie. Y
para infinito era peor: `Decimal(Double.infinity)` trapea. Con `nil`, quien compara decide, y
decide lo mismo que para «coinciden» y para «sube»: no decorar.

Hoy la API manda el mismo literal en ambos campos cuando no hay rebaja, así que `==` sobre
los dobles decodificados funcionaría por accidente. Deja de funcionar en cuanto un céntimo
de diferencia venga de un redondeo del servidor: la pantalla enseñaría un tachado idéntico
al importe de al lado y una fila de «Descuento −0,00 $», que es la cláusula 3 del requisito
incumplida por la vía más tonta.

`discountAmount` **sí se deja en crudo** (`119.96 - 105.41 = 14.549999…`): lo consume el
formateador de moneda, que ya redondea a `14,55 $`. Y no se le pone el mismo corte en
céntimos a propósito — la pregunta «¿hay rebaja?» la responde `hasDiscount`, y solo él. Si
`discountAmount` también la respondiera devolviendo `0`, habría dos sitios donde se
contesta lo mismo y podrían discrepar. El `-0.0001` que devuelve para una diferencia por
debajo del céntimo es inalcanzable en pantalla: para llegar a pintarse, `hasDiscount` ya
habría dicho que no hay nada que pintar.

### Los textos de accesibilidad viven en `CartCopy.swift`, fuera de SwiftUI

Un fichero nuevo, sin `import SwiftUI`, con dos funciones puras
(`lineAccessibilityLabel(_:)`, `totalAccessibilityLabel(_:)`) que devuelven `String`. La
vista las pasa a `.accessibilityLabel(...)`.

*Alternativa descartada:* componer el texto inline en `CartLineRow`. Se compone igual de
bien, pero entonces la única forma de comprobar qué oye VoiceOver es un UI test, y los UI
tests de este repo no entran en la firma de verificación. Una regla que nadie puede
comprobar no es una regla: es una intención. Sacar el string a una función pura la convierte
en cuatro `#expect` que corren en `swift test`.

**Pero cubre la mitad, y conviene decirlo aquí para que el acuerdo no afirme de más.** Los
cuatro tests fijan QUÉ DICE el texto; ninguno fija que la vista lo USE. Se puede borrar el
`.accessibilityLabel(...)` de `CartView` y los tests de `Packages/Features`, los `AppTests` y
los dos snapshots siguen verdes — un PNG no captura accesibilidad. Cerrar esa mitad pide un
UI test o un inspector de vistas: lo primero está fuera de la firma por decisión de
`kit.conf`, lo segundo es una dependencia nueva. Se queda abierto, dicho, y NO contado como
cubierto.

*Alternativa descartada:* colgarlo de `CartLine` como propiedad calculada. Metería copy de
presentación en el modelo de dominio de la feature, que es la capa que precisamente no sabe
que existe una pantalla. Un fichero aparte no lo hereda.

El nombre `CartCopy` no lleva ninguno de los sufijos que `.archlint.yml` clasifica
(`ViewModel`/`Logic`/`Service`/`Store`/`Module`), así que ninguna regla de capa le aplica —
como debe ser: no es una capa, son literales.

### El desglose se queda en el `footer` de la `Section`

`CartTotalFooter` pasa de una fila a cuatro (unidades, subtotal, descuento, total) dentro
del mismo `} footer: {` que ya usa.

*Alternativa considerada:* moverlo a su propia `Section`, que le daría el tamaño de texto de
una fila normal en vez del de un pie. Es un cambio de layout mayor por una mejora que **no
sabemos que haga falta**: un pie de sección renderiza en `.caption`, y cuatro filas ahí
pueden leerse bien o pueden quedar diminutas. La decisión se toma mirando el PNG regrabado,
no aquí — y si hay que mover la sección, se mueve entonces con la imagen delante. Esto está
en `tasks.md` como un paso explícito, no como un «ya se verá».

**RESUELTO mirando `testContentKit.kit.png`:** se queda en el pie. Las cuatro filas se leen
sin esfuerzo, con los importes alineados a la derecha y el total en semibold destacando sobre
los otros tres. No hace falta el cambio de layout mayor.

### La fila apila los dos importes; no los pone uno al lado del otro

Esta decisión **no estaba en el diseño original** —iba como riesgo, no como decisión— y la
tomó el snapshot. El primer intento puso el importe tachado a la izquierda del que se paga,
tal cual el boceto acordado. La foto lo tumbó: tres cifras no caben a lo ancho de un iPhone
junto a un título como «Apple MacBook Pro 14 Inch Space Grey», y los números se partían a
mitad — `US$1,620.0` con un `0` suelto en la línea siguiente y el tachado cruzando las dos,
y `US$1,481` / `.20` al lado. Comparado con la referencia anterior, donde nada se partía, la
pantalla habría salido de este cambio menos legible de lo que entró.

La solución es un `VStack(alignment: .trailing)` con el «antes» tachado encima del que se
paga. Cada cifra vuelve a caber entera, el título deja de partirse, y la relación entre las
dos se lee mejor que en horizontal: es la forma en que se enseña una rebaja en casi
cualquier sitio.

Vale la pena decir cómo se cazó: el test estaba **verde** en los dos intentos. Un snapshot
recién grabado siempre lo está. Lo destapó abrir el PNG, que es exactamente el paso que
`tasks.md` pone como tarea propia por lo que pasó con «4 artículo».

### La ausencia de descuento se fotografía

Se añade un snapshot de un carrito con `total == discountedTotal`. Es el único artefacto que
prueba la cláusula 3 —que la pantalla **no** gana ruido— sobre la pantalla de verdad; un
`#expect(cart.hasDiscount == false)` prueba el modelo, no lo que se pinta.

## Risks / Trade-offs

- **El snapshot regrabado sale verde diga lo que diga la imagen** → el criterio de
  aceptación es mirar el PNG, y `tasks.md` lo pone como paso propio con lo que hay que
  buscar en él. Es el mismo fallo que produjo «4 artículo», ya documentado en `CartView`.
- **Tres cifras en una fila estrecha** (`4 × 29,99 $`, `119,96 $`, `105,41 $`) pueden
  atropellarse con títulos largos o Dynamic Type grande → **el riesgo se materializó**, y la
  mitigación funcionó: el snapshot con el título largo lo enseñó a la primera. Resuelto
  apilando los importes, arriba § Decisions. Dynamic Type extremo sigue sin estar cubierto
  por esta firma y no se afirma que lo esté.
- **`total` se decodifica como `Double` no opcional**, igual que `price`, `quantity` y
  `discountedTotal`, y a diferencia de `thumbnail`. Si el campo desapareciera de la
  respuesta, la pantalla falla con su error de siempre en vez de enseñar en silencio un
  carrito sin descuentos → el trade-off es deliberado: una pantalla que degrada callada a
  «aquí no hay rebaja» vuelve al problema que este cambio arregla, y encima sin que nadie se
  entere. Fallar ruidosamente es lo que hace que se note.
- **El desglose repite información** que ya está en las líneas → es deliberado: la queja no
  es que falte el dato, es que la resta no se ve. Verla dos veces, en la fila y en el pie,
  es lo que se pidió.
