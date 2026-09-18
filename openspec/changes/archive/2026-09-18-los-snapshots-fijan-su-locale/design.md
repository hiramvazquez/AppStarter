## Context

Ver `proposal.md` — Why. Lo que condiciona el cómo:

- `AppStarter.xcodeproj` está en `.gitignore` y lo genera xcodegen desde `project.yml`
  (`Scripts/bootstrap.sh`). El CI lo regenera en cada corrida; `kit.conf` no, prueba el que
  haya en disco.
- El esquema `AppStarter` es uno solo para `AppTests`, `AppSnapshotTests` y `AppUITests`. No
  hay test plans.
- `kit.conf` verifica con `build-for-testing` + `test-without-building` sobre
  `platform=iOS Simulator,name=iPhone 17`; el CI usa `xcodebuild test` sobre `iPhone 17 Pro`.
- La app no tiene recursos de localización (ni `.xcstrings` ni `.lproj`): sus textos —«4
  artículos»— están escritos en el código y no cambian con el idioma del proceso.
- SnapshotTesting resuelve a la 1.19.4: una referencia que falta se graba sola y ese test
  falla esa vez.

## Goals / Non-Goals

**Goals:**

- Que el locale del proceso de test lo diga el repo, en un solo sitio.
- Que las dos referencias del carrito se graben y se comparen con ese locale.

**Non-Goals:**

- Hacer que el CI quede verde por cualquier vía. Si detrás del locale queda otra diferencia,
  se mide y se decide aparte (ver el límite en los criterios de aceptación).
- Proteger los snapshots contra cualquier otra fuente de variación (versión de iOS, modelo de
  simulador). Eso es del cambio del Xcode.

## Decisions

### 1. Se fija en el esquema, no en los comandos ni en la vista

`schemes.AppStarter.test` gana `language: en` y `region: US`.

Medido el 2026-09-18 con un proyecto sonda —una app vacía y un test alojado que imprime
`Locale.current` y formatea `540.0` como USD—, xcodegen 2.46.0 y el mismo flujo que `kit.conf`
(`build-for-testing` + `test-without-building`, `name=iPhone 17`):

| Esquema | `TestAction` generado | `Locale.current` | Importe |
|---|---|---|---|
| con `language`/`region` | `language = "en"`, `region = "US"` | `en_US` | `$540.00` |
| sin ellos (control) | — | `en_ES@rg=mxzzzz` | `US$540.00` |

Es decir: xcodegen acepta las dos claves, el ajuste llega al proceso de test, y es ese ajuste
—no otra cosa— lo que cambia el símbolo.

Alternativas descartadas:

- **`-testLanguage en -testRegion US` en los comandos.** Habría que escribirlo en `kit.conf` y
  en `ci.yml`, dos sitios que se desincronizan, y quien lance los tests desde Xcode se queda
  fuera. El repo ya decidió lo mismo con `UI_TEST_OFFLINE`: va en el esquema porque es lo
  único que leen todos.
- **`.environment(\.locale, …)` en `captura`.** No llega. Los importes entran en el `Text` ya
  como `String`, salidos de `.formatted(.currency(code:))`, que lee el locale del proceso y no
  el entorno de SwiftUI. Para que llegara habría que reescribir `CartView` con
  `Text(_:format:)`: cambiar el producto para acomodar al test.
- **Cambiar el locale del simulador.** Es configuración de cada máquina, no del repo: el
  siguiente simulador que se cree vuelve a heredar el del sistema.
- **Bajar `precision`.** Descartado en la propuesta.

### 2. `en_US`, y no un locale en español

Es el entorno en el que el CI ya pasa todo menos estos dos tests: 28 de 30 entre `AppTests` y
`AppSnapshotTests`, y los 10 `XCUITests`, que en local no se ejecutan. Fijar `en_US` deja el CI como está y cambia solo la máquina de
desarrollo, que es donde se pueden ver las consecuencias antes de empujar. Que el runner corra
en `en_US` es una suposición —la imagen de GitHub no dice otra cosa y el log no lo imprime—,
y es la última vez que importa.

Fijar un locale en español movería el entorno de los tres targets en el CI a la vez, sin
poder probarlo antes. Y no ahorraría regrabar: `es_MX` formatea `USD 540.00`, que tampoco es lo
que hay en las referencias —el `US$540.00` sale del híbrido `es_ES@rg=mxzzzz` de esta
máquina—.

Como la app no tiene localización, fijar el idioma no cambia ningún texto suyo. Afecta a los
formateadores y a las cadenas que pone el sistema.

### 3. Se regraba borrando las dos referencias, con el destino de `kit.conf`

Se borran los dos PNG y se corre la suite: SnapshotTesting graba las que faltan y falla esa
pasada; la segunda compara. No se toca `record:` ni ninguna variable, así que no hay modo de
grabación que pueda quedarse puesto.

Se graba con el mismo destino con el que se verifica (`name=iPhone 17`), para que la máquina
que fotografía sea la que compara. En esta máquina hay dos simuladores con ese nombre —iOS 26.5
e iOS 27.0— y `xcodebuild` elige uno sin avisar; cuál, no está medido. En local da igual porque
grabar y verificar usan el mismo comando. De cara al CI, que compara en iOS 26.2, forma parte
del riesgo que recoge el límite de los criterios.

### 4. Antes de regrabar, la premisa se comprueba con los propios tests

Con el esquema ya fijado y las referencias **viejas**, los dos tests de contenido tienen que
pasar a fallar en local —hoy pasan—, y los otros cuatro de la suite seguir en verde. Eso
prueba sobre el proyecto de verdad, no sobre la sonda, que el ajuste llega al proceso de
`AppSnapshotTests`, y no añade ni una línea.

Alternativa descartada: **una aserción `Locale.current == en_US` en la suite.** Sería un
segundo sitio diciendo el locale. El esquema es generado, es uno, y no hay test plan que lo
pise; y si el CI sigue rojo, la imagen del `xcresult` dice más que la aserción.

## Risks / Trade-offs

- **[El `.xcodeproj` de disco es anterior a `project.yml`]** → `/kit-verifica` probaría el
  esquema viejo y firmaría verde contra las referencias viejas. Mitigación: la tarea 1.2
  regenera y comprueba con `grep` que el esquema lleva las dos claves, y la 1.3 no se puede
  cumplir con el esquema viejo.
- **[Queda una diferencia de render entre iOS 26.2 y el simulador local]** → no se puede
  medir hasta que el locale no estorbe. Mitigación: es el límite escrito en los criterios, con
  lo que se hace si ocurre.
- **[Alguna otra referencia cambia en local al pasar a `en_US`]** → poco probable: todas pasan
  hoy en el CI. Mitigación: `kit.conf` corre `AppSnapshotTests` entero; si alguna cae, se
  anota y se decide, no se regraba de paso.
- **[Proyectos generados antes del cambio]** → a quien no regenere le fallan los dos tests en
  local. Está dicho en Impact; el mensaje de commit lo repite.
