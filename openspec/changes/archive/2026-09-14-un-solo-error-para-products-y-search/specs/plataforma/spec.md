# Plataforma — delta

## MODIFIED Requirements

### Requirement: Una cancelación que se lanza no se le presenta al usuario como error

Una feature cuya `Logic` **lanza** un error de dominio que representa cancelación SHALL
cumplir las cuatro cosas, o no lanzarlo:

1. su `mapError` SHALL traducir `APIError.Category.cancelled` a ese caso, no a `.unknown`;
2. ese caso SHALL tener `isRetryable == false` — ofrecer «Reintentar» sobre algo cancelado
   invita a deshacer la decisión que se acaba de tomar;
3. el caso SHALL estar registrado en el `CancellationRecognizing` de la app, para que
   `BaseViewModel` lo descarte antes de llegar a `setError`;
4. la feature SHALL devolver la fase a un estado del que se pueda salir, y SHALL hacerlo
   solo si su `Task` sigue viva.

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

**Y se aplica sea el error propio de la feature o compartido.** Desde este cambio, Products y
Search lanzan `CatalogError.cancelled`, que vive en `Packages/Platform/Sources/Networking`: que
el tipo sea de dos features no las exime de las cuatro cláusulas, y que viva fuera de
`Packages/Features` no las saca del requisito.

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

La receta se eligió para no envejecer, y este cambio la dejaba **subnotificando**: mirando solo
`Packages/Features/Sources` devuelve 9 ficheros y ya no ve a Products ni a Search, que son dos
de las features a las que el requisito aplica. Lo cazó el revisor ejecutándola, no leyéndola —y
es el mismo defecto que el requisito previene, un nivel más arriba: no envejeció el número,
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

## ADDED Requirements

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
