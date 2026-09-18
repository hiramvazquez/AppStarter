# Los snapshots fijan su locale

## Why

El job `App (xcodebuild test: unit + snapshot + UI, offline)` del CI está en rojo por dos
tests y solo por ellos: `CartSnapshotTests.testContentKit` y
`CartSnapshotTests.testContentSinDescuentoKit` («Snapshot "kit" does not match reference»).
Medido el 2026-09-18 en las cuatro corridas en las que ese job ha llegado a ejecutarse desde
que existe la pantalla —`35022613870`, `35284398983`, `35287341372` y `35358222748`—: en las
cuatro fallan esos dos tests y ninguno más, y en la última son 2 fallos de 30.

**La causa, medida.** `CartView` pinta los importes con
`.formatted(.currency(code: "USD"))`, que formatea con el locale del proceso, y nada en el
esquema de test lo fija. En la máquina donde se graban las referencias el locale es
`es_ES@rg=mxzzzz` y el importe sale `US$540.00`; en `en_US` el mismo importe sale `$540.00`:

```bash
swift - <<'EOF'
import Foundation
for id in ["en_US", "es_ES@rg=mxzzzz"] {
    print(id, "→", 540.0.formatted(.currency(code: "USD").locale(Locale(identifier: id))))
}
EOF
# en_US → $540.00
# es_ES@rg=mxzzzz → US$540.00
```

La referencia `AppSnapshotTests/__Snapshots__/CartSnapshotTests/testContentKit.kit.png` lleva
escrito `US$1,620.00`, `US$1,481.20`, `US$3,280.19`: es la foto de esa máquina. En un runner
que formatee de otra manera cambian todos los importes de la pantalla a la vez, y eso no cabe
en el 98 % de `precision`. Las otras cuatro referencias del directorio —vacío y error, sin un
solo importe— pasan en los dos sitios.

**El defecto nació con la pantalla, no el 15.** La referencia original, la de `8ade3eb`
(2026-09-07), ya trae `US$3,280.19` (`git show 8ade3eb:AppSnapshotTests/__Snapshots__/CartSnapshotTests/testContentKit.kit.png`).
No se vio antes porque el job `app` lleva `needs: packages` y quedó `skipped` en las doce
corridas de `main` entre el 2026-09-07 y el 2026-09-15; la última vez que corrió en verde
(`048febd`) es anterior al carrito. Estos dos tests no han pasado nunca en el CI.

**Esto corrige una pista escrita.** `el-ci-fija-el-xcode-con-el-que-prueba` dejó este rojo
fuera de su alcance con la hipótesis de que era «otra cara del mismo desfase» de Xcode, y
pidió medirlo en su cambio. Medido: el locale basta para romper los dos tests, y fijar el
Xcode del CI no lo cambia. Lo que **no** está medido es si además hay una diferencia de
render entre el iOS del runner (26.2) y el del simulador local: mientras el locale difiera no
se puede separar una cosa de la otra, así que queda como límite en los criterios.

El repo ya conocía el mecanismo —`Packages/Features/Tests/CartFeatureTests/CartCopyTests.swift:19`
lo documenta y lo esquiva componiendo el esperado con el formateador—; al snapshot no le
llegó.

## What Changes

- `project.yml`: la acción `test` del esquema `AppStarter` fija `language: en` y
  `region: US`, con el porqué escrito al lado, como ya hace con `UI_TEST_OFFLINE`. Es el único
  sitio: el esquema lo leen igual Xcode, `kit.conf` y el CI.
- Se regraban, con el esquema ya fijado, las dos referencias que hoy llevan el locale de la
  máquina: `testContentKit.kit.png` y `testContentSinDescuentoKit.kit.png`.
- `openspec/specs/plataforma/spec.md` gana el requisito que lo convierte en norma: una
  referencia de snapshot no depende del locale de quien la graba ni de quien la compara.

No cambia ningún fichero Swift: ni `CartView`, ni `CartSnapshotTests.swift`, ni
`SnapshotHelpers.swift`.

## Capabilities

### Modified Capabilities

- `plataforma`: requisito nuevo —«Los tests de la app corren con un locale fijado»—. No
  modifica ninguno de los existentes.

## Fuera de alcance

- **Cómo formatea `CartView` los importes.** `.formatted(.currency(code: "USD"))` sigue
  igual. Que la pantalla respete el locale del usuario es comportamiento de producto
  correcto; lo que sobraba era que el test heredara el de la máquina.
- **Las otras cuatro referencias de `CartSnapshotTests` y las de `Diagnostics`, `Gallery` y
  `Uploads`.** Pasan hoy en local y en el CI. No se regraban; si alguna deja de pasar con el
  esquema fijado es un hallazgo, se anota y se decide por escrito.
- **El Xcode y el simulador del CI.** Son de `el-ci-fija-el-xcode-con-el-que-prueba`, que
  sigue sin commitear y no se toca desde aquí. Los dos cambios son independientes: ninguno
  necesita al otro para aplicarse.
- **`precision` y `perceptualPrecision`.** No se relajan. Subir la tolerancia hasta que quepa
  un símbolo de moneda distinto es dejar de mirar la pantalla.
- **Que `kit.conf` no regenera el proyecto.** `AppStarter.xcodeproj` está en `.gitignore` y
  `/kit-verifica` prueba el que haya en disco, no el que `project.yml` generaría. Aquí se
  resuelve con una tarea (regenerar antes de verificar); decidir si la puerta debe
  regenerarlo siempre es otra conversación.
- **`AppUITests` en local.** Siguen fuera de `kit.conf`, como declara su `LIMITES`.

## Criterios de aceptación

- [ ] `project.yml` declara `language: en` y `region: US` en `schemes.AppStarter.test`, y tras
      `Scripts/bootstrap.sh` el esquema generado los lleva:
      `grep -E 'language = "en"|region = "US"' AppStarter.xcodeproj/xcshareddata/xcschemes/AppStarter.xcscheme`
      devuelve dos líneas.
- [ ] `git diff --stat` del cambio toca `project.yml`, las dos referencias PNG nombradas
      arriba y `openspec/`. Ningún `.swift`, ninguna otra referencia.
- [ ] Las dos referencias regrabadas muestran los importes como `$1,620.00`, sin `US`
      delante. Se comprueba abriendo los dos PNG.
- [ ] `/kit-verifica` en verde con el proyecto regenerado, y `/kit-revisa` sin hallazgos que
      bloqueen.
- [ ] **El job `App` del CI en verde** sobre el commit del cambio, con el número de run
      escrito en `tasks.md`. Es la única prueba de que la referencia ya no depende de la
      máquina: en local solo hay una máquina.

      **Límite, dicho antes de empezar**: el locale es causa suficiente del rojo, medida; que
      sea la única no se puede saber hasta quitarla. Si con el locale fijado los dos tests
      siguen fallando en el CI, este cambio **no** se da por fallido ni se improvisa sobre
      él: se anota el run, se compara la imagen que pintó el runner —va en el artefacto
      `TestResults.xcresult` de la corrida— con la referencia, y se decide por escrito si lo
      que queda entra aquí o es de `el-ci-fija-el-xcode-con-el-que-prueba`.

## Impact

- `project.yml` — dos claves y su comentario en la acción `test` del esquema.
- `AppSnapshotTests/__Snapshots__/CartSnapshotTests/testContentKit.kit.png` y
  `testContentSinDescuentoKit.kit.png` — regrabadas.
- `openspec/specs/plataforma/spec.md` — un requisito añadido al archivar.
- El esquema es uno solo para `AppTests`, `AppSnapshotTests` y `AppUITests`, así que los tres
  pasan a correr en `en_US` en cualquier máquina. En el CI los tres pasan hoy salvo los dos
  tests de este cambio; qué locale usa el runner no está medido —el log no lo imprime— y con
  el esquema fijado deja de importar.
- Quien tenga el proyecto generado de antes tiene que volver a correr `Scripts/bootstrap.sh`:
  hasta entonces su esquema no fija nada y los dos tests le fallarán en local contra las
  referencias nuevas.
