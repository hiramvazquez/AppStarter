# plataforma Specification

## Purpose

Contrato de la capa de plataforma de AppStarter: qué garantizan los kits propios
(`AppFoundation`, `CoreNetworking`) a las features que los consumen, en las partes que
tienen comportamiento observable por el usuario.

Cubre solo lo verificado hasta hoy. Un requisito que no esté aquí no es que no exista: es
que nadie lo ha escrito todavía, y se añade cuando un cambio lo toque.

## Requirements

### Requirement: Cancelación del trabajo en vuelo al desmontar una pantalla

Una pantalla montada con `ScreenContainer` SHALL cancelar su trabajo asíncrono en vuelo
cuando la vista sea eliminada de la jerarquía de navegación, y SHALL NOT cancelarlo cuando
la vista quede únicamente cubierta por otra empujada encima.

El comportamiento se controla con `ScreenContainer(_:cancelsInFlightWorkOnRemoval:)`, cuyo
valor por defecto es `true` desde AppFoundation 1.3.0.

Cada pantalla que se aparte del default SHALL declarar por qué en el propio código.

#### Scenario: La pantalla se elimina de la jerarquía

- **WHEN** el usuario hace pop de una pantalla que tiene una carga en curso
- **THEN** el trabajo en vuelo se cancela
- **AND** no se entrega ningún resultado a una vista que ya no existe

#### Scenario: La pantalla queda cubierta por un push

- **WHEN** el usuario empuja otra pantalla encima de una que tiene una carga en curso
- **THEN** el trabajo en vuelo continúa
- **AND** al volver atrás la carga sigue siendo válida y no se repite

#### Scenario: El trabajo debe sobrevivir a su pantalla

- **WHEN** la pantalla es `UploadsView`, que sube una foto con barra de progreso
- **THEN** pasa `cancelsInFlightWorkOnRemoval: false`
- **AND** la subida continúa aunque el usuario navegue fuera

#### Scenario: Un login en vuelo pierde su pantalla

- **WHEN** `LoginView` tiene una petición de login en curso y su vista se elimina
- **THEN** la petición se cancela
- **AND** `LoginView` se queda con el default del kit, sin pasar el parámetro

Decidido por el owner el 2026-09-05: **el login se cancela**. Un login sin pantalla no
tiene a quién entregarle el resultado — ni la sesión que lo pidió, ni el formulario que
recogería el error. Y a diferencia de la subida de Uploads, repetirlo es barato: el usuario
vuelve a la pantalla y lo intenta otra vez, sin haber perdido nada por el camino.

### Requirement: El usuario no ve errores internos

Un error envuelto (`WrappedError`) SHALL presentar al usuario únicamente el mensaje de la
capa que lo envuelve. El error interno SHALL quedar disponible para el log y el
diagnóstico, y SHALL NOT aparecer en pantalla.

#### Scenario: Un fallo de red envuelto por una capa de dominio

- **WHEN** una operación falla y el error se envuelve antes de llegar a la vista
- **THEN** el texto en pantalla es el de la capa que envuelve
- **AND** el error original no forma parte de ese texto

### Requirement: Versión mínima de los kits

Los manifiestos del proyecto SHALL declarar AppFoundation `1.3.2` o superior y
CoreNetworking `1.2.2` o superior, en los tres sitios donde vive el suelo de versión:
`project.yml`, `Packages/Platform/Package.swift` y `Packages/Features/Package.swift`.

Por debajo de esas versiones el proyecto arrastra un fallo de seguridad ya corregido
(AppFoundation 1.2.6, el error interno visible para el usuario).

Por debajo de AppFoundation `1.3.2` el proyecto además no compila con un toolchain Swift
6.4 o superior: `DomainError` queda aislado al MainActor y ningún tipo de error de dominio
puede conformarlo desde código `nonisolated`.

#### Scenario: Se resuelve el grafo de dependencias

- **WHEN** se ejecuta `swift package update` o `xcodebuild -resolvePackageDependencies`
- **THEN** los tres `Package.resolved` quedan en AppFoundation 1.3.2 o superior
- **AND** en CoreNetworking 1.2.2 o superior

#### Scenario: Se compila con un toolchain Swift 6.4 o superior

- **WHEN** se construye cualquiera de los dos paquetes con el toolchain que trae el Xcode
  que resuelve el SDK
- **THEN** ningún tipo que conforma `DomainError` falla con `conformance ... crosses into
  main actor-isolated code`
- **AND** ningún tipo de error de dominio del repo necesita anotarse para conseguirlo

### Requirement: Dónde vive un helper de test compartido

Un helper de test (mock, spy o utilidad) que necesiten **dos o más** targets `*FeatureTests`
SHALL vivir en `PlatformTestSupport`, y SHALL NOT duplicarse en cada target.

Un helper que solo use un target SHALL quedarse privado en él: mover a `PlatformTestSupport`
algo con un único consumidor convierte una decisión local en superficie pública para nadie.

#### Scenario: Un segundo target necesita un helper que ya existe

- **WHEN** un target de test necesita un helper que ya está escrito en otro target
- **THEN** el helper se mueve a `PlatformTestSupport` y ambos lo importan
- **AND** no queda ninguna copia privada

#### Scenario: Un helper con un solo consumidor

- **WHEN** solo un target de test usa un helper
- **THEN** se queda privado en ese target

### Requirement: Un texto de error que ven dos pantallas se escribe una vez

Un **par título+mensaje** que dos o más features muestran al usuario para el mismo error
SHALL estar definido una sola vez en `Domain`, y SHALL NOT escribirse como literal en cada
feature.

La unidad es el **par**, no el literal suelto: un mensaje puede repetirse acompañado de
títulos distintos —«No se pudo capturar» y «No se pudo guardar» comparten «Inténtalo de
nuevo.»— y esos son errores DISTINTOS que dan la casualidad de decir lo mismo. Atarlos a una
constante común los haría cambiar juntos sin motivo.

`Domain` SHALL seguir sin dependencias: los textos se guardan como `String`, nunca como el
tipo de presentación (`ScreenError`), que pertenece a la capa de UI.

Un **fixture de test** que reproduzca uno de esos pares SHALL leerlo también de `Domain`: si
lo escribe a mano, la imagen de referencia sigue verde mientras el texto real ya cambió.

#### Scenario: Dos features muestran el mismo error

- **WHEN** dos features presentan el mismo error de dominio con el mismo texto
- **THEN** el título y el mensaje salen de la misma constante en `Domain`
- **AND** cambiar el texto en un sitio lo cambia en las dos pantallas

#### Scenario: Dos errores distintos comparten mensaje

- **WHEN** dos features usan el mismo mensaje con títulos distintos
- **THEN** cada una lo conserva como literal propio
- **AND** no se unifican, porque no son el mismo error

#### Scenario: Un fixture de snapshot reproduce un par canónico

- **WHEN** un test de snapshot monta un estado de error con un par que vive en `Domain`
- **THEN** lo lee de la constante, no lo escribe a mano

### Requirement: Una cancelación que se lanza no se le presenta al usuario como error

Una feature cuya `Logic` **lanza** un error de dominio que representa cancelación SHALL
cumplir las cuatro cosas, o no lanzarlo:

1. su traducción de `APIError` SHALL llevar `APIError.Category.cancelled` a ese caso, no a
   `.unknown` — **la escriba la feature o la herede de una pieza compartida**;
2. ese caso SHALL tener `isRetryable == false` — ofrecer «Reintentar» sobre algo cancelado
   invita a deshacer la decisión que se acaba de tomar;
3. el caso SHALL estar registrado en el `CancellationRecognizing` de la app, para que
   `BaseViewModel` lo descarte antes de llegar a `setError`;
4. la feature SHALL devolver la fase a un estado del que se pueda salir, y SHALL hacerlo
   solo si su `Task` sigue viva.

*La cláusula 1 decía «su `mapError` SHALL traducir…», y nombraba una función que desde este
cambio ya no existe: Cart, Gallery y ProductDetail la heredan de `TransportMappable`. Enmendada
el 2026-09-14 para hablar de la traducción y no del sitio donde se escribe. Lo cazó el revisor;
ninguna herramienta lo detecta, porque `openspec validate` no compara la spec con el código.*

*Y las cláusulas 2 y 4 siguen siendo de la FEATURE aunque el default venga de fuera: heredar la
traducción no exime de comprobarla. Cada una conserva sus tests, y son ellas las que se ponen
rojas si el default deja de valer.*

La cuarta no es cosmética: `performLoad`/`performActivity` salen de una cancelación
reconocida por un `return` seco que no toca `phase`, así que la fase transitoria puesta
ANTES de arrancar se queda puesta y la pantalla se cuelga en `.loading` para siempre —sin
contenido, sin error, sin reintentar—, que es peor que mostrar el error. Y el reset tiene que
mirar `Task.isCancelled` porque `performLoad` cancela la carga anterior al arrancar la
nueva: sin esa condición, la superada le quita el indicador de progreso a la que la superó.

**El requisito se aplica a la cancelación que llega desde la red, que la pantalla nunca pidió
y que por tanto no debe presentar.** Y se aplica por lo que el error SIGNIFICA, no por cómo
se llame el caso: `UploadsError.captureCancelled` no se llama `cancelled` y entra igual en el
razonamiento.

**Y se aplica sea el error propio de la feature o compartido.** Products y Search lanzan
`CatalogError.cancelled`, que vive en `Packages/Platform/Sources/Networking`: que el tipo sea de
dos features no las exime de las cuatro cláusulas, y que viva fuera de `Packages/Features` no las
saca del requisito. Lo mismo vale para quien herede la traducción de una pieza compartida sin
compartir el tipo.

Quedan fuera dos clases de cancelación, cada una por su motivo:

- **La que no se lanza.** Una feature cuya operación no es `throws` y guarda la cancelación
  como dato para pintarla —`DiagnosticsFeature` y su `DiagnosticsResult`— nunca llega a
  `BaseViewModel`, así que no le aplica.
- **La que no viene de la red y la pantalla presenta a sabiendas.**
  `UploadsError.captureCancelled` nace de `CameraCaptureError.cancelled` —el usuario cerrando
  la cámara sin disparar—, y ahí la cancelación ES el resultado de la pantalla
  («Cancelado / No se tomó ninguna foto.»). Cumple la cláusula 2 y NO debe cumplir las otras
  tres.

**Aquí no va un censo de las features que cumplen.** La versión anterior de este requisito
enumeraba «de las diez features… cuatro tienen un caso», y el número caducó con el primer
cambio que añadió una: al llegar `CartFeature` eran once y cinco. Un recuento sobre código
que el requisito no toca envejece solo y nadie vuelve a contarlo, así que lo que manda es el
criterio de arriba. Quien necesite el recuento de hoy, que lo mida — **en las dos capas**, que
es donde viven los errores de dominio desde que uno se comparte:

```bash
grep -rln "enum [A-Za-z]*Error: DomainError" Packages/Features/Sources Packages/Platform/Sources
grep -rn  "case .*[Cc]ancel" Packages/Features/Sources Packages/Platform/Sources   # a filtrar por SIGNIFICADO
```

*Ojo con la primera receta desde este cambio: `CartError`, `GalleryError` y `ProductDetailError`
ya no se declaran `: DomainError` sino `: TransportMappable`, que lo refina. Quien la ejecute a
la letra verá tres menos. Es el mismo modo de fallo que el párrafo de abajo describe —envejece el
comando, no el número— y se deja escrito en vez de reescribir la receta a ciegas: arreglarla es
otra decisión, con su propia medición.*

La receta se eligió para no envejecer, y un cambio anterior la dejaba **subnotificando**: mirando
solo `Packages/Features/Sources` devuelve 9 ficheros y ya no ve a Products ni a Search, que son
dos de las features a las que el requisito aplica. Lo cazó el revisor ejecutándola, no leyéndola
—y es el mismo defecto que el requisito previene, un nivel más arriba: no envejeció el número,
envejeció **el comando que lo produce**.

#### Scenario: Una carga cancelada con la pantalla montada

- **WHEN** una carga de una feature que lanza cancelación falla con ella y la `Task` NO está cancelada
- **THEN** el view model no queda en estado de error
- **AND** tampoco queda en `.loading`: la pantalla se puede seguir usando

#### Scenario: Una carga superada por otra

- **WHEN** una segunda carga cancela a la primera y sigue en vuelo
- **THEN** la primera, al desenrollarse, no toca la fase
- **AND** la segunda conserva su indicador de progreso

#### Scenario: Un error de dominio normal

- **WHEN** una carga falla por un error que no es cancelación
- **THEN** el reconocedor no lo intercepta
- **AND** la pantalla muestra su error como siempre

#### Scenario: Una feature que expone la cancelación como dato

- **WHEN** una feature guarda el caso de cancelación en su resultado en vez de lanzarlo
- **THEN** este requisito no le aplica
- **AND** puede presentarlo como parte de su contenido

#### Scenario: Una feature nueva que lanza cancelación de red

- **WHEN** se añade una feature cuya `Logic` traduce `APIError.Category.cancelled` a un caso propio
- **THEN** ese caso queda registrado en el `CancellationRecognizing` de la app
- **AND** hay un test que se pone rojo si se quita del registro

#### Scenario: Dos features que comparten el tipo de error

- **WHEN** dos features lanzan el mismo error de dominio, que vive fuera de `Packages/Features`
- **THEN** las cuatro cláusulas les siguen aplicando a las dos
- **AND** la receta que cuenta los errores de dominio las ve

#### Scenario: Una feature que hereda la traducción sin compartir el tipo

- **WHEN** una feature obtiene su traducción de `APIError` de una pieza compartida, conservando su
  propio tipo de error
- **THEN** las cuatro cláusulas le siguen aplicando
- **AND** es ella, y no la pieza compartida, la que tiene un test que se pone rojo si su caso de
  cancelación deja de traducirse o pasa a ser reintentable

### Requirement: El catálogo tiene un solo tipo de error

Las features que consumen `ProductsServicing` y traducen los mismos fallos de red SHALL
compartir un único tipo de error del dominio, en vez de declarar uno por feature.

1. SHALL existir `CatalogError` en `Networking`, con los casos `offline`, `server`, `cancelled`
   y `unknown`.
2. `ProductsFeature` y `SearchFeature` SHALL usarlo, y NO SHALL declarar un error propio con
   esos mismos casos.
3. `CatalogError` NO SHALL importar ninguna feature: la dependencia va de la feature a la
   plataforma, nunca al revés.

   *Las cláusulas 1 y 3 decían `Domain`, y era un diseño ilegal en este proyecto:
   `.archlint.yml` declara `Domain: allowedImports: [Foundation]`, así que allí no se puede
   importar `AppFoundation` —de donde viene `ScreenError`— ni `CoreNetworking` —de donde viene
   `APIError`—. Lo cazó el archlint al compilar, no la revisión. `Networking` ya importa los dos
   legalmente, ya depende de `Domain` para leer `ErrorCopy`, y las features ya dependen de él.
   Corregido por escrito el 2026-09-14 antes de seguir.*
4. `.cancelled` NO SHALL ser reintentable, y el resto de casos SÍ.
5. El mapeo desde `APIError` SHALL traducir una cancelación del transporte a `.cancelled`, no a
   `.unknown`.

Las cláusulas 4 y 5 no son nuevas: es lo que `ProductsError` y `SearchError` ya hacían por
separado, y lo que sus tests fijan. Se escriben aquí porque al fundirse en un solo tipo pasan a
ser una promesa de la plataforma y no de cada feature.

La 3 es la que mantiene la dirección de la dependencia. `Domain` ya declara en `.archlint.yml`
que no puede importar `*Feature`, así que la cláusula no añade una regla: la hace explícita
donde se va a leer.

**Límite declarado.** Esto cubre el par Products/Search, que comparte los cuatro casos. Las
demás features conservan su error porque **no comparten el conjunto**: `FavoritesError` tiene
dos casos y `CartError` cinco. Un tipo común para todas exigiría casos que nadie usa.

#### Scenario: Una cancelación del transporte

- **WHEN** el servicio falla con una cancelación mientras Products o Search cargan
- **THEN** el error del dominio es `.cancelled`
- **AND** no es reintentable

#### Scenario: Un fallo de servidor

- **WHEN** el servicio falla con un error de servidor
- **THEN** el error del dominio es `.server`
- **AND** es reintentable

#### Scenario: Una feature con otros casos

- **WHEN** una feature necesita casos que `CatalogError` no tiene
- **THEN** conserva su propio error
- **AND** no se le añaden casos a `CatalogError` para acomodarla

### Requirement: La traducción del transporte al dominio se escribe una vez

Las features cuya `Logic` traduce `APIError` a un error de dominio con los casos `offline`,
`notFound`, `server`, `cancelled` y `unknown` SHALL obtener esa traducción de una pieza compartida
de `Networking`, en vez de declararla cada una.

1. SHALL existir en `Networking` una pieza que, dado un `APIError`, produzca el caso del dominio
   que le corresponde, y que dé el `isRetryable` de esos cinco casos.
2. Una categoría de `APIError` que la pieza no enumere SHALL producir `unknown`. `APIError.Category`
   tiene trece casos y las features nombran cuatro: el resto cae ahí, y eso SHALL estar fijado por
   un test en el nivel compartido, no en cada feature.
3. `.notFound` y `.cancelled` NO SHALL ser reintentables; los demás casos SÍ.
4. **El `screenError` NO se comparte**, y esto es una decisión, no un olvido: cada feature conserva
   el suyo. `CartError.notFound` dice «Sin carrito / No encontramos el carrito de esta cuenta.»
   donde Gallery y ProductDetail usan `ErrorCopy.NotFound`, porque en el carrito el texto de
   producto sería falso — lo que no existe es el carrito, no un producto.
5. La pieza compartida NO SHALL importar ninguna feature: la dependencia va de la feature a la
   plataforma, nunca al revés.
6. Una feature que NO tenga esos cinco casos conserva su propia traducción y NO SHALL forzarse a
   encajar. Añadir casos a la pieza compartida para acomodar a una feature está prohibido, por la
   misma razón que ya lo está en `CatalogError`.
7. **Heredar la traducción NO exime de clasificar los casos propios.** Una feature que obtenga su
   `isRetryable` de la pieza compartida SHALL tener un test que enumere sus casos de forma
   **exhaustiva para el compilador**, de modo que añadir uno nuevo NO compile hasta decidir si es
   reintentable. Ese test SHALL comparar la clasificación explícita contra el valor heredado, así
   que falla también si los dos dejan de coincidir.

La 7 cierra lo que la extracción se llevó por delante. El default de la pieza compartida está
escrito por EXCLUSIÓN —es lo que permite que un caso propio de una feature herede sin que el
protocolo lo conozca—, y esa misma virtud es el agujero: antes, un `switch` exhaustivo en cada
`Logic` no compilaba hasta clasificar el caso nuevo; después, hereda «reintentable» en silencio.
El caso que lo hace visible: un `unauthorized` en una galería ofrece «Reintentar» sobre un 401 que
no va a funcionar nunca, con todos los tests en verde.

Va en el test y no en producción a propósito, y está medido: un `switch` en cada `Logic` devuelve
la duplicación que este requisito existe para quitar —las features que comparten los cinco casos lo
escribirían idéntico—, mientras que dentro del test de reintentabilidad que cada una ya tiene, los
cuerpos difieren y el detector no ve nada. Que la garantía viva en un test es una decisión con su
coste declarado: si alguien lo borra, desaparece sin que nada avise.

La 4 es la que distingue este requisito de una fusión de tipos. Cart y Gallery son hoy el mismo
enum salvo por ese arm, y fusionarlos obligaría a elegir una de las dos copys: lo que se comparte
es la traducción, que es lógica, no el texto que ve el usuario.

La 2 existe porque cada copia de ese `switch` era una oportunidad de olvidar una categoría, y con
el mapeo escrito tres veces nadie comprobaba las nueve que ninguna feature nombra.

#### Scenario: Una cancelación del transporte en una feature que comparte la traducción

- **WHEN** el servicio falla con una cancelación mientras carga el carrito, la galería o la ficha
- **THEN** el error del dominio es `cancelled`
- **AND** no es reintentable

#### Scenario: Una categoría que ninguna feature enumera

- **WHEN** el servicio falla con una categoría que la pieza compartida no nombra
- **THEN** el error del dominio es `unknown`
- **AND** hay un test en el nivel compartido que lo fija

#### Scenario: El carrito ausente conserva su propio texto

- **WHEN** la carga del carrito falla con `notFound`
- **THEN** el texto que ve el usuario es el del carrito, no el de producto
- **AND** ese texto sigue viviendo en la feature, no en la pieza compartida

#### Scenario: Una feature con otro conjunto de casos

- **WHEN** una feature traduce `APIError` pero no tiene los cinco casos
- **THEN** conserva su propia traducción
- **AND** no se le añaden casos a la pieza compartida para acomodarla

#### Scenario: Se añade un caso nuevo a una feature que hereda la traducción

- **WHEN** alguien añade un caso a un error de dominio que obtiene su `isRetryable` de la pieza
  compartida
- **THEN** el test de esa feature no compila hasta que el caso queda clasificado
- **AND** no hereda «reintentable» en silencio

#### Scenario: El valor heredado deja de coincidir con lo que la feature decide

- **WHEN** el default de la pieza compartida cambia y contradice la clasificación explícita de una
  feature
- **THEN** es el test de esa feature el que se pone rojo
- **AND** no solo el de la pieza compartida

### Requirement: Un contrato que implementa un actor se declara nonisolated

Los dos paquetes se compilan con `defaultIsolation(MainActor)`, así que un protocolo sin
anotación explícita queda aislado al MainActor y un `actor` no puede conformarlo.

Todo protocolo `Sendable` de este repo que tenga —en producción o en tests— al menos un
conformante declarado como `actor` SHALL declararse `nonisolated`. Cuando ese protocolo
traiga implementaciones por defecto en una `extension`, la `extension` SHALL declararse
`nonisolated` también: sin eso, el aislamiento vuelve a entrar por los miembros heredados y
son los conformantes los que tienen que anotarse uno a uno.

Un protocolo cuyos conformantes son todos `@MainActor` SHALL NOT anotarse: marcarlo
`nonisolated` mueve el fallo al conformante en vez de resolverlo.

El incumplimiento no es una cuestión de estilo — rompe el build con `actor 'X' cannot
conform to global-actor-isolated protocol 'Y'`.

#### Scenario: Se añade un Store o Service implementado como actor

- **WHEN** se escribe un `*Storing`/`*Servicing` cuya implementación o cuyo doble de test es
  un `actor`
- **THEN** el protocolo está declarado `nonisolated`
- **AND** los dos paquetes compilan sin que el `actor` necesite dejar de serlo

#### Scenario: El protocolo trae implementaciones por defecto

- **WHEN** un protocolo `nonisolated` de este repo aporta implementaciones por defecto en una
  `extension`
- **THEN** esa `extension` también está declarada `nonisolated`
- **AND** sus conformantes compilan sin anotación propia

#### Scenario: Todos los conformantes viven en el MainActor

- **WHEN** el único conformante de un protocolo es un tipo `@MainActor` que toca estado de UI
- **THEN** el protocolo se queda sin anotar
- **AND** el build sigue en verde

### Requirement: El toolchain con el que se construye el proyecto está documentado

`AGENTS.md` SHALL decir que el proyecto se construye con el toolchain que trae el Xcode
instalado, y SHALL recoger el síntoma de usar otro distinto.

Un toolchain de swift.org más antiguo que el de Xcode —el que deja en el PATH un gestor
como swiftly— falla con `unknown argument: '-target-arch-variant'` y con
`build planning stopped due to build-tool plugin failures`. Ninguno de los dos mensajes
menciona el toolchain, así que sin documentarlo el fallo se diagnostica como un problema del
código del repo, que es lo que pasó al actualizar a Xcode 27.

#### Scenario: Alguien clona el repo con otro toolchain en el PATH

- **WHEN** se ejecuta `swift build` y el build muere en `build-tool plugin failures`
- **THEN** `AGENTS.md` permite identificar el toolchain como la causa
- **AND** dice cómo seleccionar el de Xcode
