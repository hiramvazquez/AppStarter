# Tareas

Devolver al compilador la obligación de decidir, sin devolver la duplicación. El diseño está en
`design.md` y viene con las dos alternativas descartadas **medidas**, no intuidas.

## Producción

- [x] 1. `CartError`, `GalleryError` y `ProductDetailError` pasan a ser `CaseIterable`.
- [x] 2. El aviso que hoy llevan los tres comentarios —«un caso nuevo hereda `true` sin que el
      compilador te pregunte»— deja de ser la mitigación y pasa a apuntar al test que ahora sí lo
      impide. No se borra: sigue explicando por qué el default es por exclusión.

## Tests

- [x] 3. `CartModelTests.retryability`: recorre `CartError.allCases` con un `switch` exhaustivo que
      clasifique los cinco casos y lo compare con `isRetryable`.
- [x] 4. `GalleryLogicTests`: lo mismo sobre `GalleryError.allCases`.
- [x] 5. `ProductDetailLogicTests.reintentabilidad`: lo mismo sobre `ProductDetailError.allCases`,
      con `favoriteStorageFailure` clasificado explícitamente en vez de heredado en silencio.

      Los tres van DENTRO del test de reintentabilidad que cada feature ya tiene, y no en un test
      nuevo, para no añadir superficie: esa aserción ya tiene su sitio.

      *Aquí decía que un test propio «crea el grupo `0d7f0aa593` (5 líneas, 2 copias)». **No
      reproduce.** El experimento que lo produjo ponía el tipo en la FIRMA, que el detector no
      huella —solo huella lo que va entre las llaves—, así que comparaba cuerpos idénticos. Con el
      tipo dentro del cuerpo, que es como quedaría de verdad (`CartError.allCases`), no agrupa.
      Corregido el 2026-09-14; lo cazó el revisor.*

## Que la garantía sea de verdad

- [x] 6. Comprobarlo AÑADIENDO un caso de verdad a uno de los tres enums y viendo
      `error: switch must be exhaustive`. No vale leer el código: la garantía o la da el
      compilador o no la da nadie. Luego se revierte.

      *Hecho el 2026-09-14, y hubo que hacerlo DOS veces porque la primera no probaba lo que yo
      decía. Añadí `case unauthorized` a `GalleryError` y salió el error esperado… pero en
      `GalleryLogic.swift:47`, que es el `switch` de `screenError` — una barrera que YA existía
      antes de este cambio. El compilador paró ahí y nunca llegó al test, así que esa medición no
      demostraba nada sobre lo que este cambio aporta.*

      *La comprobación que sí lo demuestra: añadir el caso **y darle su arm en `screenError`**.
      Entonces el producto compila —`Build complete!`— y es el test el que corta:*
      `GalleryLogicTests.swift:91:13: error: switch must be exhaustive`. *Ésa es la barrera nueva.
      Sin ella, arreglar el `screenError` bastaba y `isRetryable` heredaba `true` en silencio, que
      es exactamente el agujero que este cambio cierra.*
- [x] 7. Comprobar también el otro brazo: que el test falla si el default heredado deja de
      coincidir con la clasificación explícita —mutando `TransportMappable`—, que es lo que este
      `switch` aporta y el de producción no podía.

      *Hecho: quitando `notFound` del default se ponen rojas **las tres** features, cada una con
      dos issues —el assert suelto y el del `switch`—. Antes de este cambio, ese mismo `switch` no
      existía y la discrepancia entre lo heredado y lo decidido no la veía nadie.*

## Cierre

- [x] 8. Medir los duplicados contra HEAD y declarar el resultado. Hoy son 2; este cambio NO debe
      añadir ninguno.
- [x] 9. `/kit-verifica` en verde.
