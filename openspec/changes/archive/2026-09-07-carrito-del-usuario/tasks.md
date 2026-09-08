# Tareas

Cada tarea se cierra con `/kit-revisa` sobre su rodaja, no al final del cambio.

- [x] 1. `CartLine`/`Cart`, `CartError` y `CartService` (petición, DTO, decodificación) —
      con tests. Van juntos: el target no enlaza con el modelo sin la firma del servicio, y
      una rodaja que no compila no se puede revisar. Se separaban en el plan inicial; queda
      escrito porque el troceo tiene ese límite y conviene saberlo.
- [x] 2. `CartLogic`: carga, vacío y mapeo del error — con tests
- [x] 3. `CartViewModel`: fases, vacío y cancelación — con tests que fijan la FASE, no solo
      `hasError`
- [x] 4. `CartView`, `CartModule`, `AppRoute.cart`, `RootView` y el empuje desde `Profile`,
      con test de los DOS brazos: con perfil empuja el id cargado, sin perfil no empuja
- [x] 5. `CartError.cancelled` registrado en `AppCancellationRecognizer`, con su test en
      `AppTests` — lo exige la spec `plataforma` vigente y no lo cubría nada
- [x] 6. Snapshots: contenido en un tema, vacío y error en los dos, fotografiados sobre
      `CartContent` para que el `.task` no se lleve la captura. Sin fixture offline: la
      pantalla no está en el recorrido de `-UITestOffline`, que arranca en Products.
- [x] 7. Delta sobre la spec `plataforma`: fuera el censo de features, que este cambio
      caduca
- [x] 8. `/kit-verifica` en verde
- [x] 9. `CartModule` entra en `AppTests/CompositionRootTests.swift` — el juez de
      aceptación DEVOLVIÓ el cambio por esto. `RootView` resuelve `CartViewModelFactory` en
      RUNTIME (`RootView.swift:95`): el `case .cart` lo garantiza el compilador, pero el
      `resolve` no lo garantizaba nadie, porque `CartModule.register` no se ejecutaba en
      ningún test del repo (los snapshots construyen el ViewModel a mano). Se podía borrar
      un `register` de `CartModule` con las suites enteras en verde y la app reventaba al
      abrir «Mi carrito» — la única feature de once en esa situación. No es alcance nuevo:
      es el criterio 5 del acuerdo, que pedía que `RootView` resolviera la ruta.

> La numeración anterior saltaba de la 2 a la 4 sin explicación, y los checkboxes se
> quedaron sin indexar, así que el diff firmado llevaba todas las tareas sin marcar. Lo
> señaló el juez de aceptación. Reescrita entera.

> La tarea 9 salió del juez de aceptación, no del plan inicial. La 8 (`/kit-verifica`)
> se repitió después de ella: el diff cambió y la firma anterior dejó de valer.
