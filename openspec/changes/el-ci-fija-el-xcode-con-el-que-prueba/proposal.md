# El CI fija el Xcode con el que prueba

## Why

El CI no prueba ninguna versión concreta de Xcode. Los tres jobs de macOS
(`packages`, `app`, `integration`) eligen el toolchain así
(`.github/workflows/ci.yml:32-38`, y repetido en `:70-77` y `:129-135`):

```yaml
LATEST=$(ls -d /Applications/Xcode_*.app 2>/dev/null | sort -V | tail -n 1)
sudo xcode-select -s "$LATEST"
```

Lo que valida el CI es, literalmente, «lo que traiga hoy la imagen del runner». No hay
versión declarada ni fijada, así que una actualización de imagen puede romper o arreglar el
repo sin que nadie toque una línea de código, y nadie podría decir contra qué versión está
verde `main`.

**Esto ya costó dos días de rojo.** `d575e75` («el proyecto vuelve a compilar con Xcode 27 y
Swift 6.4», 2026-09-15) arregló el repo para el toolchain de desarrollo y lo rompió para el
del CI. El acuerdo `el-dto-de-uploads-no-se-aisla` cerró ese rojo concreto —el DTO de
Uploads— y dejó esta causa de fondo explícitamente fuera de su alcance, para el owner. Este
cambio es esa decisión.

**La medición que la sostiene.** Reproductor mínimo con los tres ajustes de
`Packages/Features/Package.swift:8-12` (`defaultIsolation(MainActor)`,
`InferIsolatedConformances`, `NonisolatedNonsendingByDefault`), comprobado el **2026-09-17**
con `swiftc -typecheck` sobre toolchains reales instalados con swiftly:

| Toolchain | El DTO sin `nonisolated` | Con `nonisolated` |
|---|---|---|
| Swift 6.2.4 (Xcode 26.3, el del CI) | error `[#IsolatedConformances]` | compila |
| Swift 6.3.3 | error `[#IsolatedConformances]` | compila |
| Swift 6.4 (Xcode 27, el de desarrollo) | **compila** | compila |

Tres consecuencias, y ninguna es la que se suponía al abrir la sesión:

1. **El selector no flota hacia 27 hoy, pero flota.** Comprobado el 2026-09-17 con
   `gh api repos/actions/runner-images/contents/images/macos/macos-15-arm64-Readme.md`: la
   imagen `macos-15` trae Xcode 16.0 … 26.0.1, 26.1.1, 26.2 y 26.3, y **ninguna 27**. Así que
   `sort -V | tail -n 1` resuelve hoy a Xcode 26.3 → Swift 6.2.4. Xcode 27 solo está en la
   imagen `xcode-27`, en preview (actions/runner-images#14404). El problema no es que hoy
   elija mal: es que elegirá otra cosa el día que la imagen cambie, sin que nadie lo decida.
2. **No es «6.2 contra 6.4»: es «6.4 contra todo lo anterior».** 6.3.3 rechaza el código
   igual que 6.2.4.
3. **El toolchain viejo es el estricto, y el nuevo es quien falla en avisar.** Una sonda que
   fuerza el no-aislamiento —pasar el valor a un genérico `T: Encodable & Sendable` con
   `sending`— da el **mismo** error en 6.4 que en 6.2.4. Es decir: 6.4 sigue infiriendo la
   conformidad como aislada al MainActor, y lo único que cambió es que dejó de diagnosticar
   su uso desde un contexto que hereda el aislamiento del llamante.

El punto 3 es el que obliga a este cambio y no solo al arreglo del DTO: **verificar en local
con Xcode 27 no cubre esta clase de error**, y `/kit-verifica` en verde no dice nada sobre
ella. Sin una versión fijada en el CI, la única red que queda es que alguien mire los logs.

*Sin confirmar, y no hace falta para decidir:* hay issues abiertos de no-enforcement de
SE-0470 (swiftlang/swift#91971 y #85742) y un pitch para enmendar SE-0466/SE-0470 en los
foros de Swift. No he determinado si lo que hace 6.4 es deliberado o un hueco; el arreglo
—declarar `nonisolated` el tipo— es correcto en las tres versiones en cualquier caso.

## What Changes

- **Una versión fijada, y escrita.** Los tres jobs de macOS dejan el selector `ls | sort -V |
  tail` y pasan a `maxim-lobanov/setup-xcode@v1` con una variable `XCODE_SOPORTADO` del
  `env:` del workflow. **El owner ha fijado el suelo en Xcode 26.3 (Swift 6.2.4)** el
  2026-09-17: es lo que el CI ejecuta hoy de facto y la más nueva que ofrece `macos-15`.
  AppStarter es una app, no una librería publicada: no hay consumidores que obliguen a un
  suelo más bajo.
- **Junto a la versión, por qué esa.** El `env:` lleva la fecha de la comprobación y el
  comando que la sustenta, para que subirla exija rehacer la medición y no un pálpito.
- **Un job de aviso temprano en Xcode 27, no bloqueante.** En la imagen `xcode-27`, con
  `continue-on-error: true` mientras esa imagen siga en preview, y con la condición para
  volverlo bloqueante escrita en el propio workflow. Cubre el sentido contrario al job
  fijado: que un cambio que compila en 26.3 no rompa el toolchain con el que se desarrolla,
  que es exactamente lo que hizo `d575e75` al revés.
- **El desfase, declarado donde se decide.** `AGENTS.md` ya tiene la sección de qué toolchain
  usar en local; gana la otra mitad: que el CI valida con otro, cuál es, y que una
  verificación local con Xcode 27 no prueba compatibilidad con él.

## Capabilities

### New Capabilities

- `ci-toolchain`: qué versión de toolchain valida la integración continua, que esa versión
  sea explícita y no resuelta, y que el toolchain de desarrollo tenga aviso temprano.

### Modified Capabilities

- `plataforma`: el requisito «El toolchain con el que se construye el proyecto está
  documentado» hoy solo cubre el toolchain local y el síntoma de usar otro. Gana el desfase
  con el CI: qué versión valida la integración continua y que verificar en local no cubre lo
  que ella comprueba.

## Fuera de alcance

- **El rojo de `CartSnapshotTests`.** Es una causa distinta de esta, y la cerró su propio
  cambio, `los-snapshots-fijan-su-locale`, archivado el 2026-09-18: los importes se
  formateaban con el locale del proceso. El job `app` está en verde en `main` desde el run
  `35389558928`, con Xcode 26.3 contra referencias grabadas con Xcode 27.

  *Corregido el 2026-09-19, por escrito:* este punto daba ese rojo por abierto y dejaba una
  pista para su cambio, que era «otra cara del mismo desfase» de Xcode. Se midió allí y la
  pista era falsa: la causa era el locale.
- **Cambiar la versión de Xcode con la que se desarrolla en local.** Sigue siendo la 27; lo
  que cambia es que el desfase queda escrito en vez de implícito.
- **Revisar el resto de `d575e75`** —los siete protocolos anotados y `DeviceCameraCapture`—.
  El job fijado dirá si alguno más falla en 26.3, y si lo hace es un hallazgo nuevo.
- **Meter la sonda de aislamiento en `kit.conf`.** El acuerdo
  `el-dto-de-uploads-no-se-aisla` ya lo dejó fuera por escrito, y sigue fuera: no es una
  línea, y decidir qué más vigila la puerta es otra conversación.
- **La imagen `macos-15` en sí.** No se migra a `macos-26` ni a ninguna otra; solo se fija el
  Xcode que se usa dentro de ella.

## Criterios de aceptación

- [ ] `.github/workflows/ci.yml` no contiene ninguna aparición de `sort -V | tail -n 1` ni de
      `xcode-select -s "$LATEST"`. Comprobable con
      `grep -nE 'sort -V|LATEST' .github/workflows/ci.yml`, que sale vacío.
- [ ] Los tres jobs de macOS (`packages`, `app`, `integration`) seleccionan el toolchain con
      `maxim-lobanov/setup-xcode@v1` y `xcode-version: ${{ env.XCODE_SOPORTADO }}`, y ninguno
      declara la versión a pelo en su propio paso.
- [ ] El `env:` del workflow declara `XCODE_SOPORTADO: "26.3.0"` y, en el comentario contiguo,
      la fecha de la comprobación (2026-09-17), el comando `gh api
      repos/actions/runner-images/contents/images/macos/macos-15-arm64-Readme.md` y la lista
      de versiones que la imagen ofrecía ese día. *Corregido al implementar, el 2026-09-19:*
      aquí decía `"26.3"`. `setup-xcode` lo trata como un rango y elegiría un 26.3.x posterior
      sin avisar, que contradice la spec («sigue validando exactamente la versión que tiene
      escrita»); lo cazó el revisor.
- [ ] Existe un job `aviso-toolchain-desarrollo` que corre en `runs-on: xcode-27`, lleva
      `continue-on-error: true`, y su comentario dice la condición concreta para volverlo
      bloqueante (que la imagen `xcode-27` salga de preview) con el enlace de seguimiento
      actions/runner-images#14404.
- [ ] `AGENTS.md` dice, en su sección de toolchain, con qué Xcode valida el CI y que una
      verificación local con Xcode 27 no cubre la compatibilidad con él. Comprobable leyendo
      la sección: nombra la versión `26.3`.
- [ ] La spec nueva `ci-toolchain` existe y `openspec validate` pasa sobre el cambio.
- [ ] **El run del CI sobre este cambio imprime `26.3` en el paso de versiones de los tres
      jobs de macOS**, y el job de aviso aparece en la corrida sin hacerla fallar aunque él
      falle. El número de run queda escrito en `tasks.md`.
- [ ] Si el job fijado destapa un error de compilación en 26.3 que hoy no se ve, se anota con
      su fichero y su diagnóstico y se decide por escrito si entra aquí o es un hallazgo
      aparte. No se van probando anotaciones contra el CI hasta que pase.

## Impact

| Fichero | Qué cambia |
|---|---|
| `.github/workflows/ci.yml` | los tres pasos de selección de toolchain, un `env:` nuevo y un job de aviso |
| `AGENTS.md` | la sección de toolchain gana el desfase con el CI |
| `README.md` | la sección de CI deja de decir que el Xcode nunca se fija, y lista el job de aviso (añadido al implementar, tarea 3.3) |
| `openspec/specs/ci-toolchain/spec.md` (al archivar) | capacidad nueva |
| `openspec/specs/plataforma/spec.md` (al archivar) | el requisito de toolchain documentado |

Ningún efecto sobre el código del producto ni sobre la app en ejecución: este cambio no toca
`Packages/`, `App/` ni `project.yml`. Lo que cambia es contra qué versión se mide el repo, y
que esa versión deje de moverse sola.
