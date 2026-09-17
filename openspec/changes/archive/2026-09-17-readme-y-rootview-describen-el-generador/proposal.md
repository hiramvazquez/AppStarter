# `README.md` y `RootView` dejan de describir el generador antiguo

## Why

`huecos-del-generador-en-el-repo` (2026-09-17) corrige en `AGENTS.md` lo que hace
`generate-feature` en modo multi y deja fuera, a propósito, otros dos textos que siguen describiendo
el comportamiento antiguo:

- **`README.md`**, en «El kit, usado de verdad», dice que el generador añade «el
  `import`/`case`/módulo en `App/AppModule.swift`/`App/AppRoute.swift`». No nombra
  `App/RootView.swift` ni `project.yml`. En «Añadir una feature nueva» manda seguir «los pasos
  manuales que imprime el comando», entre ellos el destino en `App/RootView.swift` y el producto en
  `project.yml` «si no hay marker `# archinit:products`».
- **El comentario de documentación de `struct RootView`** (`App/RootView.swift`) dice que
  `generate-feature` «never edits this file» y que imprime el `switch` arm para añadirlo a mano.

Las dos cosas son falsas con AppFoundation 1.4.2, la versión que resuelven hoy los dos
`Packages/*/Package.resolved`, y lo eran igual con la 1.4.1, que era la resuelta cuando se
midió esto. Se ve en `Plugins/GenerateFeature/MultiMode.swift`, en `registerAppWiring` y
`registerAppModule`. Y se midió el 2026-09-17 en un worktree desechable
creado desde `e5fcc64` (ya borrado), con la orden de la guía, sin `--disable-sandbox`:
`swift package --allow-writing-to-package-directory generate-feature Probe --api`, desde
`Packages/Features`. El generador imprimió:

```
App/AppModule.swift: import ProbeFeature añadido
App/RootView.swift: import ProbeFeature añadido
App/RootView.swift: destino ProbeView añadido
project.yml: producto ProbeFeature añadido
…
App/AppModule.swift: añadido 'ProbeModule()'.
App/AppRoute.swift: no existe App/AppRoute.swift — añade 'case probe' a mano.
```

`git status` enseñó modificados `App/AppModule.swift`, `App/RootView.swift`,
`Packages/Features/Package.swift` y `project.yml`. En `App/RootView.swift` entró
`case .probe: ProbeView(viewModel: Container.shared.resolve())` delante de
`// archinit:destinations`.

Hoy, quien siga el README añade a mano un destino y un producto que ya existen. Y quien lea el
comentario de `RootView` no espera que el generador edite ese fichero.

## What Changes

- **`README.md`, «El kit, usado de verdad»**: el párrafo que sigue al bloque de órdenes dice qué
  registra `generate-feature` en modo multi con AppFoundation 1.4.2:
  - el target y su test target, entre los markers de `Packages/Features/Package.swift`;
  - cada una de estas cosas si encuentra su marker: el `import` en `App/AppModule.swift` y
    `App/RootView.swift`, el módulo en `App/AppModule.swift`, el destino en `App/RootView.swift` y
    el producto en `project.yml`.

  También dice que el `case` de `AppRoute` no lo añade en este repo, y remite a `AGENTS.md` para los
  pasos que quedan a mano. La frase sobre las features que se movieron a mano desde
  `AppStarterKit/` no cambia.
- **`README.md`, «Añadir una feature nueva»**: deja de listar pasos manuales y de decir que el
  comando los imprime. Remite a `AGENTS.md` § «Si vas a añadir una feature nueva». La frase de
  `swift package archlint` y R13 no cambia.
- **`App/RootView.swift`**: el párrafo del comentario de `struct RootView` que habla del generador
  (hoy las líneas 23-27) dice qué edita el generador en este fichero y con qué markers. Dice también
  que el `case` de `AppRoute` se añade a mano en `Domain`, y remite a la misma sección de
  `AGENTS.md`. Tiene las mismas líneas que el de hoy, y ninguna línea de código cambia.

Ningún cambio de comportamiento de la app. No es **BREAKING**.

**Depende de `huecos-del-generador-en-el-repo`**, y esa condición ya se cumple: ese cambio se
archivó en `main` el 2026-09-17 (`72f9c80`, en
`openspec/changes/archive/2026-09-17-huecos-del-generador-en-el-repo/`), y `AGENTS.md` ya no dice
que el destino de `RootView.swift` se añada a mano. La tarea 1.1 lo vuelve a comprobar antes de
escribir nada.

## Capabilities

### New Capabilities

Ninguna.

### Modified Capabilities

Ninguna. Solo cambia documentación: un README y un comentario. Lleva `skip_specs: true`.

## Fuera de alcance

- **`AGENTS.md`**: su guía es de `huecos-del-generador-en-el-repo`.
- **Cualquier línea de código Swift.** En `App/RootView.swift` solo cambia el comentario.
- **El comentario de `enum AppModule`** (`App/AppModule.swift`), aunque también describe el
  generador. Dice que añade `<Name>Module()` «right below the marker» y que «nothing above it
  changes». Lo primero sigue siendo falso: la medición insertó la línea **encima** del marker. Lo
  segundo dejó de serlo en la 1.4.2, que sí toca la línea anterior para ponerle la coma
  (`Sources/GenerateFeatureSupport/ManifestEditor.swift`). El comentario sigue estando mal, y
  corregirlo es otro cambio.
- **`Packages/Platform/Sources/Domain/AppRoute.swift`, `docs/INFORME-MULTI.md` y `project.yml`**:
  no se tocan.
- **Otras citas `fichero:línea` del README que ya no apuntan bien.** Por ejemplo,
  `App/RootView.swift:108` para el destino de `.settings`, que el 2026-09-17 está en la línea 112
  (`grep -n 'case .settings' App/RootView.swift`). Este cambio no las mueve más, pero tampoco las
  corrige.
- **Los defectos del generador** (la coma, el formato, no encontrar `AppRoute` en `Domain`), que
  van a AppFoundation. Tampoco se sube la versión de AppFoundation ni de CoreNetworking.

> **Renegociado el 2026-09-17, antes de implementar.** Este acuerdo se escribió cuando el repo
> resolvía AppFoundation 1.4.1, y nombraba esa versión en el README, en el comentario de `RootView`
> y en sus criterios. El cambio del que depende, `huecos-del-generador-en-el-repo`, subió el suelo a
> **1.4.2** al archivarse ese mismo día, así que la versión resuelta es otra y su tarea 1.2 obliga a
> releer el generador, repetir la medición y corregir esto por escrito.
>
> Hecho: releído `Plugins/GenerateFeature/MultiMode.swift` en el checkout `1da0bdb` (tag `1.4.2`) y
> repetida la medición en un worktree desechable, generando `GuiaPrueba --api --local`. **El
> comportamiento que este cambio describe es el mismo**: el generador sigue registrando el target y
> su test target, el `import` en `App/AppModule.swift` y `App/RootView.swift`, el módulo, el destino
> en `App/RootView.swift` y el producto en `project.yml`, y sigue sin poder añadir el `case` de
> `AppRoute` porque lo busca en `App/AppRoute.swift`. Lo que cambia en la 1.4.2 son dos defectos que
> este cambio no describe —la coma de la lista de módulos y el formato del código generado—, y que
> por eso reducen de cuatro a dos los pasos manuales de la guía de `AGENTS.md`.
>
> Qué se corrige aquí, por tanto: los dos textos y los criterios nombran **1.4.2**, que es la
> versión que el repo resuelve. Nada más. El motivo de escribir la versión sigue siendo el de
> `design.md`: que al subir AppFoundation, un `grep` de la versión encuentre juntos el README, el
> comentario y la guía.

## Criterios de aceptación

- [ ] `openspec/changes/archive/` de la rama contiene `huecos-del-generador-en-el-repo`, y
      `grep -n 'siempre imprime' AGENTS.md` sale vacío.
- [ ] El párrafo de «El kit, usado de verdad» nombra AppFoundation 1.4.2 y los markers
      `archinit:features-begin/end`, `archinit:products-begin/end`, `// archinit:imports`,
      `// archinit:modules`, `// archinit:destinations` y `# archinit:products`, cada uno con el
      fichero que edita. Dice que el `case` de `AppRoute` no lo añade aquí, y remite a `AGENTS.md`
      § «Si vas a añadir una feature nueva».
- [ ] «Añadir una feature nueva» del README no contiene `imprime el comando`, `si no hay marker` ni
      `el destino en`. Remite a `AGENTS.md` § «Si vas a añadir una feature nueva» y conserva la
      frase de `swift package archlint` y R13.
- [ ] El comentario de `struct RootView` no contiene `never edits this file` ni `always prints`.
      Nombra AppFoundation 1.4.2, `// archinit:imports` y `// archinit:destinations`, dice que el
      `case` de `AppRoute` se añade a mano en `Domain`, y remite a `AGENTS.md` § «Si vas a añadir
      una feature nueva».
- [ ] `grep -n 'struct RootView' App/RootView.swift` da la línea 28, igual que antes del cambio.
- [ ] `git diff -U0 App/RootView.swift` solo tiene líneas `+`/`-` que empiezan por `///`.
- [ ] `git diff --stat` solo enseña `README.md` y `App/RootView.swift`.
- [ ] `Scripts/check-showcase.sh` sale con código 0.
- [ ] `/kit-verifica` en verde.

## Impact

| Fichero | Qué cambia |
|---|---|
| `README.md` | el párrafo de «El kit, usado de verdad» sobre el modo multi, y «Añadir una feature nueva» |
| `App/RootView.swift` | el párrafo del generador en el comentario de `struct RootView` |
