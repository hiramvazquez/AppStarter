# Cancelar en Perfil, Login y la subida no pinta error

## Why

Tres rutas mandan `APIError.Category.cancelled` al `default` de su `mapError`, y ninguno de
sus tres enums tiene caso de cancelación:

```
ProfileLogic.swift:72-78   default: return .unknown      ← .cancelled cae aquí
LoginLogic.swift:101-110   default: return .unknown      ← igual
UploadsLogic.swift:109-114 default: return .unknown      ← igual (la ruta de RED)
```

`.unknown` es reintentable en los tres, así que cancelar ofrece «Reintentar» sobre algo que el
usuario acaba de cancelar. Y el síntoma no es solo el error pintado: `BaseViewModel` sale de una
cancelación reconocida con un `return` seco —`_performLoad:401` sin tocar `phase`,
`_runActivity:451` **sin** llamar a `stopActivity()`—, así que la pantalla se queda colgada en
`.loading` o con el indicador puesto para siempre.

Es el mismo incumplimiento del requisito vivo `plataforma` → «Una cancelación que se lanza no se
le presenta al usuario como error» que se arregló en Galería y Detalle, y aquel cambio ya lo dejó
anotado como preexistente y fuera de su alcance.

## What Changes

Las tres rutas siguen el patrón que Cart, Gallery, ProductDetail, Products y Search ya tienen,
cláusula por cláusula:

- **`ProfileError`, `LoginError` y `UploadsError`** ganan un caso de cancelación de red, con
  `isRetryable == false` y `screenError` desde `ErrorCopy.Cancelled`, que ya existe.
- **Sus tres `mapError`** traducen `.cancelled` en vez de dejarlo caer en `.unknown`.
- **Sus tres ViewModels** devuelven la fase a un estado del que se pueda salir, solo si su `Task`
  sigue viva, y relanzan. Con una diferencia que no es cosmética: Profile y Login usan
  `performLoad`, así que les toca `setIdle()`; la subida corre bajo `activity(style: .inline)` →
  `_runActivity`, que se va sin parar la actividad, así que le toca `stopActivity()` — el mismo
  par que `ProductsViewModel:109` ya distingue.
- **`App/AppCancellationRecognizer`** registra los tres casos nuevos; su lista pasa de cuatro
  tipos a siete.
- **Tests**: por ruta, que el transporte cancelado mapea al caso nuevo, que la pantalla no queda
  en error ni colgada, y que una operación superada por otra no le quita el indicador a la que la
  superó. `AppTests/CancellationRecognizerTests` añade los tres tipos.

**`UploadsError` acaba con dos casos de cancelación, y es correcto.** `captureCancelled` nace de
que el usuario cierra la cámara y la pantalla lo presenta como su resultado —el requisito lo
excluye a propósito—; el caso nuevo nace de la red y nunca debe llegar a pantalla. Mismo nombre
coloquial, significados opuestos: por confundirlos se coló este bug en su día.

## Capabilities

### New Capabilities

Ninguna.

### Modified Capabilities

Ninguna. El requisito de `plataforma` ya exige estas cuatro cláusulas a toda feature cuya `Logic`
lance una cancelación venida de la red; este cambio lo **cumple**, no lo cambia. Por eso el
`.openspec.yaml` declara `skip_specs: true`, igual que hizo
`2026-09-14-cancelar-en-galeria-y-detalle-no-pinta-error`.

## Impact

Ficheros que se tocan, nombrados:

- `Packages/Features/Sources/ProfileFeature/ProfileLogic.swift` y `ProfileViewModel.swift`
- `Packages/Features/Sources/LoginFeature/LoginLogic.swift` y `LoginViewModel.swift`
- `Packages/Features/Sources/UploadsFeature/UploadsLogic.swift` y `UploadsViewModel.swift`
- `App/AppCancellationRecognizer.swift` y `AppTests/CancellationRecognizerTests.swift`
- Sus seis ficheros de test, y los mocks `ProfileLogicMock`, `LoginLogicMock` y
  `UploadsLogicMock`, que necesitan un `gate` para el test de «superada» — ninguno lo tiene.

`Puerta` y `RecognizerDePrueba` ya viven en `PlatformTestSupport`: los tests nuevos los importan,
no los copian.

## Fuera de alcance

- **El `logout` de Perfil.** `ProfileLogicProtocol.logout()` es `async` **sin** `throws`
  (`ProfileLogic.swift:68`) y el protocolo documenta por qué: es decisión del usuario y no hay
  nada que recuperar. No puede lanzar cancelación, así que el requisito no le aplica.
- **`UploadsError.captureCancelled`** y la ruta de cámara, por lo dicho arriba.
- **`DiagnosticsFeature`**, que guarda la cancelación como dato en vez de lanzarla.
- **Unificar los enums que están convergiendo.** Este cambio hace que seis features cumplan la
  misma norma, así que sus `mapError` e `isRetryable` se parecerán aún más y el detector lo verá.
  No se unifican aquí: `CartError` y `GalleryError` ya comparten los cinco casos y aun así su
  `screenError` difiere, que es la decisión que esa unificación exige tomar y que ya tiene su
  propio acuerdo pendiente. Ampliarlo ahora a tres features más sería decidirlo de refilón.

**Medición, con su fecha y su comando, en vez de un censo.** Lo que manda es el criterio del
requisito —toda `Logic` que traduzca `APIError.Category.cancelled` y lo lance cumple las cuatro
cláusulas—, no una lista que envejece sola. El 2026-09-14, con

```
grep -rl 'DomainError' Packages/Features/Sources Packages/Platform/Sources --include='*.swift'
```

y leyendo cada `mapError`, las únicas rutas que lo incumplían eran estas tres. `FavoritesLogic` y
`SettingsLogic` no aparecen porque no ven un `APIError` en ningún punto —leen de
almacenamiento local—, no porque se les haya dado permiso.

## Criterios de aceptación

- [x] `ProfileError`, `LoginError` y `UploadsError` SHALL tener un caso de cancelación de red con
      `isRetryable == false`.
- [x] Sus tres `mapError` SHALL traducir `APIError.Category.cancelled` a ese caso:
      `grep -A8 'func mapError'` en los tres ficheros muestra `case .cancelled`.
- [x] `AppCancellationRecognizer` SHALL reconocer los tres casos nuevos, y
      `AppTests/CancellationRecognizerTests` SHALL ponerse rojo si se quita cualquiera de ellos.
- [x] Cada una de las tres rutas SHALL tener un test que falle si su `mapError` deja de traducir
      la cancelación, y otro que falle si su pantalla queda en error o colgada.

      *Comprobado por MUTACIÓN el 2026-09-14, porque «hay un test» no es lo mismo que «el test
      fija algo» — y en el cambio anterior una mutación sobrevivió sin que nadie lo notara. Se
      rompió a propósito cada pieza y se miró qué se ponía rojo:*

      | Mutación | Resultado |
      |---|---|
      | quitar `stopActivity()` de la subida | ✘ `(viewModel.isPerformingActivity → true) == false` |
      | quitar `if !Task.isCancelled` de Perfil | ✘ solo Profile; Gallery y ProductDetail siguen verdes |
      | quitar `case .cancelled` de `ProfileLogic.mapError` | ✘ solo Profile; Login y Gallery siguen verdes |

      *Que las otras features NO se pongan rojas es la mitad que importa: prueba que cada test
      mide su propia ruta y no se apoya en el vecino.*
- [x] La subida SHALL parar la actividad con `stopActivity()`, no con `setIdle()`, y SHALL tener
      un test que se ponga rojo si se quita ese `stopActivity()`.

      *Enmienda del 2026-09-14, al implementar. El criterio pedía que el test fijara el
      `if !Task.isCancelled`, y eso en esta ruta no se puede: `activity(style:)` →
      `_runActivity` no cancela a la anterior, así que no hay subida que supere a otra y la
      mutación de esa condición sobrevive. Lo que sí se fija —y es el fallo real de esta
      pantalla— es que sin `stopActivity()` la actividad se queda puesta para siempre. La
      condición se conserva porque la cláusula 4 la exige, no porque un test la cubra.*
- [x] `/kit-verifica` en verde.
- [x] El archlint SHALL seguir en verde.
- [x] El recuento de lógica repetida SHALL medirse contra HEAD al terminar y quedar **declarado
      aquí con su medición**. Hoy son 4 grupos; este cambio hace converger más cuerpos, así que
      subirá. No se resuelve aquí, por lo dicho en Fuera de alcance.

      *Medido el 2026-09-14: **4 antes y 4 después**, y la predicción de que «subirá» era
      falsa — por compensación, no por acierto. Apareció el grupo nuevo que sí se esperaba,
      `1f074820d8`: el `mapError` de Uploads, al ganar `.cancelled`, quedó idéntico al `from`
      de `CatalogError` (`Packages/Platform/Sources/Networking/CatalogError.swift:61`). Y a la
      vez se rompió uno preexistente, `dd13b693f6` (`ProfileLogicMock.loadProfile` ≡
      `ProfileServiceMock.me`), porque `loadProfile` ganó el `gate` y el contador.*

      *`1f074820d8` no se unifica aquí, y la razón es la misma de Fuera de alcance:
      `UploadsError` tiene `captureCancelled` y `captureFailed`, que `CatalogError` no tiene ni
      debe tener —son cámara, no red—. Los cuerpos coinciden hoy; los conjuntos de casos, no.*

## Ronda 1 del revisor: AMBER, dos hallazgos

**Arreglado — `subidaCancelada` podía pasar en verde sin probar nada.** El primer
`await waitUntil { viewModel.isPerformingActivity }` no llevaba aserción detrás, y `waitUntil`
vuelve en silencio al agotar su plazo. Si `handle(.upload)` dejara de arrancar la subida, las
tres aserciones finales serían ciertas **por vacío** y el test seguiría verde dejando sin cubrir
el `stopActivity()` — la única línea que impide que la barra se quede puesta para siempre, y el
fallo entero que esta pantalla persigue. Se cierra con la aserción que Perfil, Login y Cart ya
tienen tras su espera.

*La prueba de mutación no lo cazó, y conviene entender por qué: mutar `stopActivity()` sí pone
el test rojo HOY, porque hoy la subida sí corre. El agujero no está en lo que el test mide, sino
en lo que deja de medir cuando otra cosa cambia.*

**Declarado y NO arreglado — el reconocedor se instala desde suites sin serializar.**
`BaseViewModel.cancellationRecognizer` es un `static var` de todo el proceso, y los cinco tests
nuevos lo instalan desde suites normales (`ProfileViewModelTests:173` y `:199`,
`LoginViewModelTests:52` y `:77`, `UploadsViewModelTests:70`). Cart, Products y Search meten
estos tests en una suite `.serialized` por eso mismo; Gallery y ProductDetail ya lo hacen inline,
así que esto sigue el precedente flojo en vez de inventar un riesgo.

Medido hoy: no hay colisión posible. Ningún test de esos tres targets presenta un error cuyo
`String(describing:)` sea `"cancelled"`, y ninguno depende del `DefaultCancellationRecognizer`.
**Se vuelve flaky el día que alguien añada a esos targets un test que espere ver un `.cancelled`
en pantalla** — esa es la condición de disparo, escrita para que el próximo no la descubra.

No se arregla aquí porque hacerlo bien obligaría a mover también Gallery y ProductDetail, para no
dejar dos estilos conviviendo: es un cambio sobre features que este no venía a tocar. Crecer por
hallazgo es justo lo que este acuerdo dice querer evitar.

## Presupuesto

Tres rutas, un patrón ya establecido cinco veces y ninguna decisión técnica nueva — por eso no
lleva `design.md`. **Una pasada de revisor.** El juez solo si el alcance se mueve durante la
implementación, que es cuando aporta algo que el revisor no mira.
