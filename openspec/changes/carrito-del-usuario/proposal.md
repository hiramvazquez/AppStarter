# El carrito del usuario

## Why

La app consume `/auth/*` y `/products/*` de DummyJSON y nada más. `GET /carts/user/{id}`
devuelve los carritos de un usuario con sus líneas, cantidades y totales con descuento: es
una pantalla completa —lista, estado vacío, error, reintento— que hoy no existe.

Se construye además como **prueba del kit sobre código nuevo**. Las tres pruebas anteriores
fueron modificaciones de código existente; el flujo nunca se ha ejercitado creando una
feature de cero, que es donde se toman las decisiones que de verdad se tuercen: dónde vive
un tipo, quién puede importar a quién, dónde se engancha la pantalla.

**Sin defectos plantados.** Las pruebas anteriores medían detección; esta mide **ruido**:
cuánto se reporta cuando no hay nada que encontrar.

## What Changes

- Nace `CartFeature` (generador de AppFoundation, variante `--api`): `CartView`,
  `CartViewModel`, `CartLogic`, `CartService`, `CartModule`.
- `AppRoute` gana `case cart(userId: Int)`, añadido a mano en
  `Packages/Platform/Sources/Domain/AppRoute.swift` (el generador no encuentra ese fichero,
  está documentado en `docs/INFORME-MULTI.md`).
- `ProfileView` empuja la ruta, pasando el `id` del usuario que ya tiene cargado.
- `RootView` resuelve el caso nuevo.
- Delta sobre la spec `plataforma`: se le quita el censo de features, que este cambio
  caduca (ver abajo).

### La decisión de diseño que este cambio toma

`GET /carts/user/{id}` necesita saber quién es el usuario. Ese dato lo obtiene hoy
`ProfileService` con `GET /auth/me`, y vive **dentro** de `ProfileFeature`, que
`CartFeature` no puede importar (R13).

Las tres salidas eran: duplicar la petición `/auth/me` en el servicio del carrito; subir un
proveedor de identidad a `Networking`, junto a `ProductsServicing`; o **pasar el `userId` en
la ruta**, ya que la pantalla se abre desde `Profile`, que acaba de cargarlo.

Se toma la tercera. La primera duplica una petición. La segunda es un cambio sobre la capa
compartida que ninguna pantalla necesita todavía, y crear superficie compartida para un solo
consumidor es exactamente lo que este repo evita a propósito (ver el doc comment de
`ErrorCopy`). La tercera deja `CartFeature` sin identidad propia y sin dependencias nuevas.

Su coste, dicho para que sea decisión y no descuido: la pantalla no se puede abrir por deep
link sin un `userId`, y si algún día hay más de un origen habrá que subir el proveedor a
`Networking` de todas formas.

## Fuera de alcance

- Modificar el carrito (`POST /carts/add`, borrar líneas). Solo lectura.
- Abrirlo desde cualquier sitio que no sea `Profile`, y por deep link.
- Subir un proveedor de identidad a `Networking`. Se hará el día que un segundo consumidor
  lo pida, y entonces será su propio cambio.
- Compartir `CartLine` en `Domain`. Lo usa una sola feature.

## Por qué los snapshots de vacío y de error salían en blanco

La primera versión de este documento declaró esto «límite conocido de la suite» con una causa
escrita como hecho —«el overlay de fase no llega a renderizarse bajo el host de snapshots»— y
un alcance estimado a ojo —«toca la suite entera y probablemente AppFoundation»—. **Las dos
cosas eran falsas**, y el juez de aceptación las desmontó ejecutando sondas. Queda escrito
porque la lección importa más que el arreglo: la parte comprobable (seis PNG, un solo hash
`24bfd14d74f7`) sí se había medido; la CAUSA no, y se escribió igual.

Lo que sí se midió después, con seis variantes en el mismo host y el mismo simulador:

| variante | resultado |
|---|---|
| `List`, `ScrollView`, `VStack`, `List` + `navigationTitle` | overlay pintado (`514f9cbe…`) |
| `List` + `.task { send(.load) }`, y `CartView` entera | **en blanco** (`24bfd14d…`) |

La causa es el **`.task { send(.load) }`**: al renderizar, la vista relanza la carga y la
captura se queda con ese estado transitorio en vez del que montó el test. No es el
contenedor, no es el `NavigationStack`, no es el view model y no es AppFoundation.

Y por tanto **sí era arreglable aquí**: el cuerpo se extrae a `CartContent`, que es la misma
vista sin el disparador, y las fases de vacío y error se fotografían sobre ella. El contenido
sigue yendo por `CartView` entera, que es como se ve en la app.

`GalleryView` tiene el mismo `.task { send(.load) }` y las mismas cuatro referencias en
blanco en `main`; `DiagnosticsView`/`UploadsView` mandan `.appear` y no les pasa. Arreglar
Gallery queda **fuera de este cambio** —es su propia feature y su propia decisión—, pero ya
no como «límite ajeno sin diagnosticar», sino con la causa y el patrón del arreglo escritos.

## Criterios de aceptación

- [ ] `CartLogic.load(userId:)` devuelve las líneas con su cantidad y su total con
      descuento, y traduce el fallo de red a `CartError`. Fijado por test.
- [ ] `CartError` mapea `APIError.Category` sin caer en `.unknown` para los casos que la
      pantalla distingue, y `cancelled` cumple lo que exige la spec `plataforma` vigente.
- [ ] Un usuario sin carritos produce **estado vacío**, no error ni lista en blanco. Fijado
      por test.
- [ ] `CartViewModel` no queda colgado en `.loading` en ningún camino de salida.
- [ ] `CartView` se alcanza desde `ProfileView` y `RootView` resuelve la ruta.
- [ ] Hay snapshot de la pantalla con datos, y de las fases de vacío y error en los dos
      temas. El de contenido va en UN tema: `snapshotTheme(.brand)` solo sustituye los
      estilos de loading/error/empty/banner, que `.content` no usa, así que las dos
      referencias salían byte a byte idénticas y el eje no aseveraba nada ahí.
- [ ] Ningún test nuevo pasa con el código que dice cubrir revertido. Verificado por
      mutación, uno a uno.
- [ ] `/kit-verifica` en verde.
