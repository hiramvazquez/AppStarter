# Diseño

## Context

Ver `proposal.md` — Why. Lo que importa aquí: `screenError` es una propiedad del enum, los tres
enums difieren en él, y los tres coinciden en todo lo demás. Cualquier diseño tiene que separar
esas dos mitades.

Restricciones que no se negocian:

- `.archlint.yml` declara `Domain: allowedImports: [Foundation]`, así que nada que toque
  `ScreenError` o `APIError` puede vivir en `Domain`. `Networking` ya importa los dos y las tres
  features ya dependen de él.
- Una feature no puede importar otra (R13).
- `APIError.Category` tiene **trece** casos; las features enumeran cuatro y mandan el resto al
  `default`.

## Goals / Non-Goals

**Goals.** Que la traducción del transporte exista una sola vez. Que el `screenError` de cada
feature quede intacto, byte a byte.

**Non-Goals.** Un tipo de error común a toda la app: `CatalogError` ya declara ese límite y la
spec lo respalda. Tampoco tocar las features que no traducen `APIError`.

## Decisions

**Un protocolo con los casos como requisitos `static` y las dos piezas comunes como
implementación por defecto.** Los conformantes declaran `extension CartError: … {}` y borran sus
dos funciones.

Está **probado antes de acordarlo**, no supuesto: un prototipo en Swift confirma que el
`default` cubre las categorías que nadie enumera (`.decoding` y `.timeout` → `.unknown`) y que el
`isRetryable` derivado da `false` para `.notFound` y `.cancelled` y `true` para el resto —
incluido `favoriteStorageFailure`, que es de ProductDetail y no del protocolo—. Eso significa que
**ProductDetail no necesita sobrescribir nada**, que era la duda que decidía si el protocolo
servía a tres features o solo a dos.

### Alternativas descartadas

**Fusionar `CartError` y `GalleryError` en un enum compartido.** Es lo que pedía el encargo
literal, y no se puede sin romper algo: el `screenError` vive en el enum, así que habría que
elegir una sola copy para `.notFound`. `CartModelTests.missingCartHasItsOwnCopy` lo prohíbe y
explica por qué. La variante «enum compartido + envoltorio por feature» añade más código del que
quita.

**Meterlos en `CatalogError`.** Necesitan `notFound`. El escenario «Una feature con otros casos»
de `plataforma` dice literalmente que no se le añaden casos para acomodar a una feature.

**Una función libre `mapear(_:) -> T` genérica.** Necesitaría igualmente que el llamante dijera a
qué caso va cada categoría, así que deja el `switch` en cada feature: no quita la duplicación,
solo la mueve.

## Risks / Trade-offs

- **El protocolo obliga a los cinco casos, y una feature futura podría tener cuatro** → no lo
  conforma y escribe su mapeo, como ya hacen Uploads y `CatalogError`. El protocolo no es «el
  mapeo de la app»; ese límite se declara donde vive, igual que lo hace `CatalogError`.
- **Un `isRetryable` por defecto es invisible en el sitio donde antes se leía** → lo compensan los
  tests por feature, que se conservan: si el default dejara de valer para una de ellas, se pone
  roja ahí y no en la plataforma.
- **`favoriteStorageFailure` hereda `true` por omisión, no por decisión escrita** → el test de
  ProductDetail que lo fija se conserva, y es el que convierte la herencia en contrato.

## Migration Plan

Mecánico y en un paso: se añade el protocolo, se conforman las tres, se borran las seis funciones.
No hay estado ni datos que migrar. Revertir es borrar el fichero y devolver las funciones.
