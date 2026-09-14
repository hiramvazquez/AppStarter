# Tareas

Extraer lo que está escrito tres veces, sin tocar lo que cada feature dice al usuario. El diseño
está en `design.md` y viene probado con un prototipo: el `isRetryable` por defecto sirve a las
tres, así que ninguna lo sobrescribe.

## La pieza compartida

- [x] 1. Un protocolo en `Packages/Platform/Sources/Networking/` que exija los cinco casos como
      `static` y dé por defecto la traducción desde `APIError` y el `isRetryable`. Lleva escrito su
      LÍMITE, como lo lleva `CatalogError`: no es «el mapeo de la app», y una feature con otro
      conjunto de casos no lo conforma.
- [x] 2. Su test en `Networking`: que una categoría que nadie enumera —`.decoding`, `.timeout`—
      cae en `unknown`, y que `.notFound` y `.cancelled` no son reintentables. Es la cláusula 2 del
      requisito, y va aquí y no en cada feature a propósito.

## Las tres features

- [x] 3. `CartLogic`: conforma el protocolo, borra su `mapError` y su `isRetryable`. El
      `screenError` NO se toca — «Sin carrito» se queda.
- [x] 4. `GalleryLogic`: lo mismo.
- [x] 5. `ProductDetailLogic`: lo mismo. Comprobar que `favoriteStorageFailure` sigue siendo
      reintentable sin escribir nada: lo hereda del default.

## Que no se pierda nada por el camino

- [x] 6. Los tests por feature que fijan el mapeo de `.cancelled` y que `.notFound` no es
      reintentable SE CONSERVAN. Son los que convierten la herencia en contrato: si el default
      dejara de valer para una, se pone roja ahí.
- [x] 7. `CartModelTests.missingCartHasItsOwnCopy` SHALL seguir en verde **sin tocarlo**. Es el
      test que impide que esta extracción se lleve por delante la copy del carrito.
- [x] 8. Comprobar por mutación que lo anterior no es decorativo: romper el default del protocolo
      y ver que se ponen rojas las features, no solo el test compartido.

      *Hecho el 2026-09-14, y es el resultado que decide si esta extracción fue segura:*

      | Mutación en `TransportMappable` | Qué se puso rojo |
      |---|---|
      | `isRetryable` → siempre `true` | el test compartido **y** Cart, Gallery y ProductDetail (4 fallos en features) |
      | `.cancelled` → `.unknown` en `from` | los tres tests de mapeo por feature, incluido el de Cart |
      | quitar **solo** `notFound` del default | Cart, Gallery y ProductDetail, más el compartido |

      *La tercera la trajo el revisor, y es la que importa: con las dos primeras esta tabla
      parecía probar algo que no probaba. Mutar `isRetryable` a `true` rompe también el assert de
      `.cancelled`, que sí estaba en las tres, así que las tres se ponían rojas y yo di por bueno
      que `.notFound` estaba cubierto. No lo estaba: al quitar solo `notFound`, Gallery y
      ProductDetail quedaban **enteras en verde**. Con sus dos asserts nuevos, ya no.*

      *La lección, que vale más que el arreglo: **una mutación demasiado gruesa no prueba lo que
      parece probar.** Si rompe varias cosas a la vez, el rojo puede venir de la que sí estaba
      cubierta.*

      *Lo que prueba: al perder su `mapError`, los tests de cada feature NO se volvieron
      decorativos — siguen fijando su propia ruta contra el default heredado. Si el default deja
      de valer para una, se pone roja ahí y no solo en la plataforma, que es justo lo que el
      `design.md` prometía como mitigación.*

## Cierre

- [x] 9. Medir los duplicados contra HEAD en un worktree limpio y declarar el resultado en el
      acuerdo con su medición. Hoy son 4 grupos; deben irse `3450e859ac` y `61cb3a5ed6`.

      *Medido el 2026-09-14 con `busca-duplicados.py App Packages AppTests AppSnapshotTests`, en
      un worktree limpio de `842e096` para el baseline y sobre el árbol para el resultado:
      **4 antes, 2 después**. Se fueron exactamente los dos previstos. Quedan `8389af4e6c` (el
      `body()` de tres vistas) y `1f074820d8` (Uploads ≡ `CatalogError.from`), los dos declarados
      fuera de alcance y sin tocar.*
- [x] 10. `/kit-verifica` en verde.
