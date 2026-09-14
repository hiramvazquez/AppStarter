## MODIFIED Requirements

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
