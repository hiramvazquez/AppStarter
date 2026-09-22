# ATS no se desactiva en silencio

## Why

El cambio anterior dejó seis invariantes comprobados y una lista escrita de lo que NO cubren.
El primero de esa lista es este: **nadie comprueba `App/Info.plist`**. Si alguien añade
`NSAllowsArbitraryLoads`, la app deja de exigir TLS y no salta nada: ni el lint, que solo mira
Swift, ni el escaneo de secretos, ni el revisor si ese fichero no cae en su rodaja.

Y es un incumplimiento que **no se ve leyendo el código**: la app sigue compilando, los tests
siguen verdes y las URLs del código siguen siendo `https://`. Simplemente, el sistema deja de
impedir las que no lo sean.

**Estado medido el 2026-09-22:**

- `App/Info.plist` **está versionado** en git, es XML, y hoy **no tiene**
  `NSAppTransportSecurity`: ATS queda en su valor por defecto, que es el seguro.
- Lo **genera xcodegen** fusionando `info.properties` de `project.yml` con las claves que
  sintetiza `GENERATE_INFOPLIST_FILE`. Así que hay **dos sitios** por donde ATS puede
  desactivarse: el `project.yml`, que es la fuente, y el propio plist, que alguien puede editar
  a mano y commitear.
- Es el único plist del repositorio.

## What Changes

- **`kit.conf`**: un paso nuevo, `ATS`, que falla si aparece `NSAppTransportSecurity` en
  `project.yml` o en cualquier `Info.plist` versionado.
  - El plist se lee con `plutil`, no con `grep`: hoy es XML, pero Xcode reescribe estos
    ficheros en binario sin avisar y un `grep` dejaría de ver nada, en silencio y en verde.
  - Se vigila **la clave entera**, no solo `NSAllowsArbitraryLoads`: `…InWebContent`,
    `…ForMedia`, `NSExceptionAllowsInsecureHTTPLoads` y una `NSExceptionMinimumTLSVersion` a
    la baja abren el mismo agujero por otra puerta. Si alguna vez hace falta una excepción
    —un dominio local de desarrollo—, se declara como las demás: junto a la comprobación y con
    su motivo.
- **La spec `seguridad`**: un séptimo invariante, con sus escenarios.
- **`AGENTS.md`**: la fila nueva en la tabla, y fuera la frase que decía que nadie comprueba
  el `Info.plist`, que dejará de ser cierta.

## Fuera de alcance

- **Otras claves del `Info.plist`.** Los permisos (`NSCameraUsageDescription` y compañía), los
  esquemas de URL y el resto no entran: cada uno pide su propia decisión y esto no es un
  cambio para revisar el plist entero.
- **Los plists de los targets de test.** Hoy no existen; si aparecen, el paso los verá porque
  busca por nombre, y entonces se decidirá qué hacer con ellos.
- **El CI.** La comprobación corre en la verificación local, que es donde está la puerta. El
  CI ya falla por otras vías si el plist rompe el build.
- **Mover la sesión a Keychain**, que sigue siendo su propio cambio.

## Criterios de aceptación

- [ ] `kit.conf` tiene un paso que falla si `NSAppTransportSecurity` aparece en `project.yml`
      o en un `Info.plist` versionado, y pasa con el árbol actual.
- [ ] Comprobado metiendo la clave en `project.yml`: el paso se pone rojo.
- [ ] Comprobado metiendo la clave en `App/Info.plist`: el paso se pone rojo.
- [ ] Comprobado con el plist convertido a BINARIO: el paso sigue viéndolo.
- [ ] La spec `seguridad` recoge el séptimo invariante con sus escenarios, y la lista de lo
      que las comprobaciones no cubren ya no nombra el `Info.plist`.
- [ ] `AGENTS.md` lo dice en su tabla y ya no afirma que nadie lo comprueba.
- [ ] `/kit-verifica` en verde, y el paso nuevo no añade más de un segundo.
