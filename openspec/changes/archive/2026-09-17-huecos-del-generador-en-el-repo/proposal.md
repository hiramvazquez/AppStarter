# Tres huecos del repo que salieron al probar `generate-feature`, y la subida a AppFoundation 1.4.2

## Why

El 2026-09-17 el owner probó `generate-feature` (AppFoundation 1.4.1) en un worktree desechable de
este repo con las cuatro variantes: `--api`, `--local`, `--api --local` y sin datos. Salieron tres
huecos que son de AppStarter, y varios defectos del propio generador que se arreglaron en
AppFoundation y se publicaron ese mismo día como **1.4.2**.

**`/kit-verifica` firma en verde un formato que CI rechaza.** CI ejecuta en cada paquete
(`.github/workflows/ci.yml:58`):

```sh
swift format lint --strict --configuration ../../.swift-format --recursive Sources Tests
```

`kit.conf` no tiene ningún paso de swift-format. Sobre la salida sin retocar de una feature
`--api --local` generada con la 1.4.1, `swiftlint lint --strict` da 0 violaciones en 6 ficheros y
swift-format da 117 errores (medido por el owner el 2026-09-17). Los dos cambios archivados que
tocaron el lint (`lint-estricto-y-reglas-de-los-kits-en-contexto` y
`features-pasa-swift-format-estricto`, los dos del 2026-09-15) dejaron swift-format fuera de
`kit.conf` a propósito. Los dos escribieron la consecuencia: un cambio posterior puede volver a
romper el formato con la firma en verde. La 1.4.2 ya genera código con formato limpio, pero el
hueco no es del generador: cualquier fichero escrito a mano puede romper el formato igual.

**`AGENTS.md` describe mal el generador en modo multi.** La sección «Si vas a añadir una feature
nueva» presenta el destino de `App/RootView.swift` como paso manual. Pero el generador ya hace estas
cuatro cosas, cada una si encuentra su marker (leído en `Plugins/GenerateFeature/MultiMode.swift`,
`registerAppWiring` y `registerAppModule`):

- añade el `import` en `App/AppModule.swift` y en `App/RootView.swift`;
- añade el destino `case .<nombre>:` en `App/RootView.swift`;
- añade el módulo en `App/AppModule.swift`;
- añade el producto en `project.yml`.

La guía, en cambio, no nombra el paso sin el que la app no compila: el destino que añade el
generador referencia `AppRoute.<nombre>`, y aquí `AppRoute` vive en
`Packages/Platform/Sources/Domain/AppRoute.swift`, que el generador no encuentra.

**`Packages/Features/Package.swift` se acerca al límite de `file_length`.** Medido el 2026-09-17
sobre una copia en el scratchpad, con `swiftlint lint` y el umbral bajado a 1 para leer la
cuenta: SwiftLint le cuenta **330** líneas. El aviso salta por encima de 400, y con `--strict`
es error. Con cuatro features de prueba llegó a 422, así que cada feature añade unas 23 líneas:
caben 3 más y la cuarta pone `/kit-verifica` en rojo. `.swiftlint.yml` ya excluye `Package.swift`,
pero ese glob solo encaja en la raíz, y en modo multi ahí no hay ningún manifiesto. Lo comprobó
la misma copia: un `Package.swift` en la raíz no se lintea y el de `Packages/Features/` sí.

**La guía tiene que describir la versión que el repo resuelve, y esa pasa a ser la 1.4.2.** Medido
el 2026-09-17 apuntando un worktree desechable de AppStarter a la rama que se publicó como 1.4.2 y
generando `PruebaApi --api` y `PruebaMod --api --module`:

- `swift format lint --strict` con la orden de CI sobre `Packages/Features` da 0 errores sin
  formatear nada a mano;
- el generador puso la coma al último módulo de `App/AppModule.swift` (`CartModule(),`) y dejó el
  nuevo como último, sin coma;
- con `--module` importa `<Nombre>FeatureUI`, y un nombre inválido sale con código 1 sin crear
  nada;
- la app compiló con un solo paso a mano, además de regenerar el proyecto: el `case` de
  `AppRoute`.

La 1.4.2 está publicada (tag `1.4.2` → `1da0bdb`) y su CI en GitHub pasó en verde. CoreNetworking
no tiene versión nueva: la última es 1.3.1.

## What Changes

- **Subida de AppFoundation a `1.4.2`** en los tres sitios donde vive el suelo de versión:
  `project.yml`, `Packages/Platform/Package.swift` y `Packages/Features/Package.swift`. Los dos
  `Package.resolved` versionados (`Packages/Platform` y `Packages/Features`) la resuelven, y
  también el del workspace de `AppStarter.xcodeproj`, que no se versiona. CoreNetworking se queda
  en `1.3.1`.
- **`kit.conf`** gana dos pasos, `Platform · swift-format` y `Features · swift-format`. Cada uno
  ejecuta la orden de CI de arriba desde `Packages/<paquete>`, con el mismo alcance que CI
  (`Sources` y `Tests`) y ninguno más. Van después de SwiftLint y antes de los builds. Tardan
  0,17 s y 0,64 s (medido el 2026-09-17, tres corridas, swift-format del toolchain Swift 6.4).
- **`AGENTS.md`**, en la sección «Si vas a añadir una feature nueva», pasa a decir qué registra el
  generador en modo multi y a listar los dos pasos que quedan a mano con AppFoundation 1.4.2, en
  orden:
  1. añadir `case <nombre>` a `Packages/Platform/Sources/Domain/AppRoute.swift`: el destino que
     añade el generador referencia esa ruta, y el generador la busca en `App/AppRoute.swift`, que
     aquí no existe;
  2. `xcodegen generate`, o `Scripts/bootstrap.sh`, que lo ejecuta.

  En «Generador y linter», la frase que remite a esa sección deja de decir «imprímelos»: el
  generador imprime el paso del `case`, pero con una ruta que aquí no existe, y no imprime el de
  regenerar el proyecto.
- **`.swiftlint.yml`**: en `excluded`, `Package.swift` pasa a `"**/Package.swift"`, con el motivo
  escrito al lado. Es decisión del owner, tomada el 2026-09-17 a la vista de las mediciones.
  Descartadas:
  - excluir solo de `file_length`: SwiftLint 0.65.1 no admite `excluded` por regla y avisa
    «invalid key(s)»;
  - un `swiftlint:disable file_length` en la cabecera del manifiesto;
  - dejarlo para cuando rompa.

  El coste, dicho: los dos manifiestos dejan de pasar **todas** las reglas de SwiftLint, no solo
  `file_length`. CI no los lintea hoy, porque solo mira `Sources` y `Tests`.

Ningún cambio de comportamiento de la app. No es **BREAKING**.

## Capabilities

### New Capabilities

Ninguna.

### Modified Capabilities

- `plataforma`: el requisito «Versión mínima de los kits» sube AppFoundation de `1.4.1` a `1.4.2`, y
  añade el motivo: por debajo, `generate-feature` en modo multi genera en este repo código que no
  compila o que CI rechaza por formato.

El resto del cambio —el contrato de verificación en `kit.conf`, la configuración del lint en
`.swiftlint.yml` y la guía del agente en `AGENTS.md`— no describe comportamiento del producto y no
lleva spec.

## Fuera de alcance

- **Los defectos del propio generador que siguen en la 1.4.2**, que van a AppFoundation:
  - no encuentra `AppRoute` en `Domain`: busca `App/AppRoute.swift` e imprime esa ruta;
  - deja comas finales en `Packages/Features/Package.swift`, que CI no lintea;
  - `archinit --multi` deja en `.swiftlint.yml` un `Package.swift` que no encaja con ningún
    manifiesto.
- **CoreNetworking**: no tiene versión nueva y se queda en `1.3.1`.
- **Ampliar swift-format más allá del alcance de CI.** El 2026-09-17, con
  `swift format lint --strict --configuration .swift-format --recursive <ruta>` desde la raíz,
  salen 9 avisos en `App`, 1 en `AppSnapshotTests` y 4 en `Packages/Features/Package.swift`, que
  son comas finales que escribe el generador. Llevarlo a todo el repo es decidir formatear eso, y
  es otro cambio.
- **`.github/workflows/ci.yml` y `.swift-format`**: ni la orden, ni las reglas, ni la versión.
- **Las reglas y umbrales de `.swiftlint.yml`**: solo cambia esa entrada de `excluded`.
- **Partir `Packages/Features/Package.swift`**: el generador solo escribe entre los markers
  `archinit:*`.
- **`App/AppModule.swift`, `App/RootView.swift`, `README.md` y `docs/`**, aunque también hablen del
  generador. Solo cambia la guía de `AGENTS.md`.
- **Los XCUITests** (4 fallos preexistentes y uno flaky, medidos y ajenos a esto), activar
  features de Swift y subir el mínimo de iOS.

> **Renegociado el 2026-09-17, antes de implementar.** Este apartado decía: «Este cambio no sube
> la versión de AppFoundation ni de CoreNetworking. Si una versión posterior arregla la coma o el
> formato, sus pasos se quitan de la guía en otro cambio». La 1.4.2 arregló las dos cosas el mismo
> día, y el owner decidió subirla aquí: la guía tiene que describir la versión que el repo resuelve,
> y hacerlo en dos cambios obligaba a validar una guía de cuatro pasos contra una versión con
> defectos conocidos para quitarle dos después. La lista de defectos del generador de arriba
> tampoco cita ya «no pone la coma» ni «no formatea»: dejaron de ser ciertos en la 1.4.2.

## Criterios de aceptación

- [ ] `project.yml`, `Packages/Platform/Package.swift` y `Packages/Features/Package.swift` declaran
      AppFoundation `1.4.2` y CoreNetworking `1.3.1`.
- [ ] Los dos `Package.resolved` versionados y el del workspace de `AppStarter.xcodeproj` resuelven
      `appfoundation 1.4.2`, y en los versionados no cambia ninguna otra entrada.
- [ ] `kit.conf` tiene los pasos `Platform · swift-format` y `Features · swift-format`, cada uno
      con la orden de `.github/workflows/ci.yml:58` sin cambiar ningún argumento, entre
      `SwiftLint · --strict` y `Platform · build`.
- [ ] Con un fichero de `Packages/Features/Sources` mal sangrado a propósito, la orden del paso
      `Features · swift-format` sale con código distinto de 0. Con el fichero restaurado sale con
      0. Medido una vez y deshecho.
- [ ] `.swiftlint.yml` tiene `"**/Package.swift"` en `excluded`, en lugar de `Package.swift`, con
      un comentario que dice por qué. Ninguna regla ni umbral cambia.
- [ ] `swiftlint lint --strict` desde la raíz lintea 2 ficheros menos que antes del cambio (176
      el 2026-09-17), y los que faltan son los dos `Package.swift`.
- [ ] En una copia en el scratchpad con `Packages/Features/Package.swift` por encima de 400 líneas
      y un fichero de `Sources` también por encima, `swiftlint lint --strict` con el
      `.swiftlint.yml` nuevo no informa `file_length` del manifiesto y sí del otro fichero.
- [ ] La sección «Si vas a añadir una feature nueva» de `AGENTS.md` dice qué registra el
      generador en modo multi y lista los dos pasos manuales de «What Changes», en ese orden.
      No dice que el destino de `RootView.swift` se añada a mano, no pide poner una coma ni
      formatear, y nombra AppFoundation 1.4.2 como la versión con la que se comprobó.
- [ ] En un worktree desechable con este cambio aplicado (AppFoundation 1.4.2), generando una
      feature `--api --local` y siguiendo esa sección al pie de la letra —sin formatear nada a
      mano—, salen con código 0:
      - `swiftlint lint --strict`;
      - las dos órdenes de swift-format de `kit.conf`;
      - `swift build` en `Packages/Features`;
      - `xcodebuild build-for-testing` de la app.

      El worktree se borra después, y las salidas quedan anotadas en `tasks.md`.
- [ ] `/kit-verifica` en verde.

## Impact

| Fichero | Qué cambia |
|---|---|
| `project.yml` | AppFoundation `1.4.1` → `1.4.2` |
| `Packages/Platform/Package.swift` | AppFoundation `1.4.1` → `1.4.2` |
| `Packages/Features/Package.swift` | AppFoundation `1.4.1` → `1.4.2` |
| `Packages/Platform/Package.resolved` | la entrada de `appfoundation` |
| `Packages/Features/Package.resolved` | la entrada de `appfoundation` |
| `kit.conf` | dos pasos de swift-format |
| `.swiftlint.yml` | la entrada `Package.swift` de `excluded` y su comentario |
| `AGENTS.md` | «Si vas a añadir una feature nueva» y la frase que remite a ella en «Generador y linter» |

Ningún fichero Swift de fuentes cambia: los dos `Package.swift` son manifiestos. `/kit-verifica`
tarda menos de un segundo más.
