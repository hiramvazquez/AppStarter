## ADDED Requirements

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

## MODIFIED Requirements

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
