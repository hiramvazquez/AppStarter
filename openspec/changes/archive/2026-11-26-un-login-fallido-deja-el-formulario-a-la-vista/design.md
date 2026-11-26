## Context

Ver `proposal.md` — Why. Lo que condiciona el cómo:

- `BaseViewModel` (AppFoundation 1.4.2) tiene dos primitivas para trabajo que no se puede
  esperar desde `handle(_:)`. `performLoad` mueve la **fase**: `.loading` al arrancar, y al
  fallar `.error`, que oculta el contenido. `performActivity` mueve la **actividad**: un
  indicador encima del contenido, y al fallar lo retira y presenta el error según
  `errorHandling` —`.banner`, `.alert` o `.silent`— sin tocar la fase.
- Con `.banner`, lo que se enseña es `screenError.message`, sin el título
  (`BaseViewModel.handleActivityError`).
- Una cancelación reconocida sale de las dos primitivas por un `return` que no deshace el
  estado transitorio puesto al arrancar. De ahí la cláusula 4 del requisito de cancelación de
  `plataforma`, que Login ya cumple hoy con `setIdle()`.
- `LoginView` ya pinta banners: `appear()` enseña el de sesión caducada por la misma vía.

## Goals / Non-Goals

**Goals:**

- Que un fallo del envío no mueva la fase de la pantalla de login.
- Que el cambio sea de primitiva y no de arquitectura: mismo `Logic`, misma vista, mismo
  `LoginError`.

**Non-Goals:**

- Rediseñar cómo se presentan los errores del login más allá de dejar de taparlo.
- Proteger el formulario contra el doble envío de otra forma que la que ya hay.

## Decisions

### 1. `performActivity` con `.banner`, y no otra salida

`login()` pasa a `performActivity(errorHandling: .banner)`, con el estilo de actividad por
defecto. Es la forma que este repo ya usa para un envío sobre contenido visible
(`CartViewModel.edit`), y la que el kit recomienda para un formulario.

Alternativas descartadas:

- **`.alert`.** Conserva título y mensaje, pero interrumpe con un modal que hay que cerrar
  antes de poder corregir. Los mensajes de `LoginError` se entienden solos —«Comprueba tu
  usuario y contraseña.», «Introduce tu contraseña.», «Comprueba tu red e inténtalo de
  nuevo.»—, así que el título no compra nada que justifique el modal.
- **Seguir con `performLoad` y añadir una salida a la pantalla de error.** Habría que dar un
  botón «Volver» a un error no reintentable, que es tocar el estilo de error del kit o
  escribir uno propio para una sola pantalla; y aun así el usuario pierde de vista lo que
  tecleó justo cuando tiene que revisarlo.
- **Marcar `invalidCredentials` como reintentable.** Aparecería el botón, pero reintentar
  reenvía lo mismo que se acaba de rechazar, con el formulario todavía oculto.

### 2. La cancelación devuelve la actividad, no la fase

La rama `catch LoginError.cancelled` pasa de `setIdle()` a `stopActivity()`, con la misma
guarda `if !Task.isCancelled`. Con `performActivity` lo que se queda colgado tras una
cancelación reconocida es el indicador, no la fase —que ya no se mueve—. Es, línea a línea, lo
que hace `CartViewModel.edit`, y sigue siendo la cláusula 4 de `plataforma`.

### 3. Un segundo envío sigue cancelando al primero

No se añade la guarda `guard !isPerformingActivity` que sí lleva el carrito. Allí una edición
parte del resultado de la anterior y cancelarla la deshace; aquí dos envíos son
independientes y gana el último, que es lo que ya pasa hoy y lo que fija el test «un login
superado no le quita el indicador al que lo superó». Cambiarlo sería otro comportamiento, no
este arreglo.

### 4. Los tests nuevos se ven rojos antes de cambiar nada, y por el motivo correcto

Los tests del rechazo y del campo vacío se escriben antes que el cambio de `login()`, y se
ejecutan contra el código de hoy esperando `inFlightLoad`, que es la `Task` que hoy existe.
Tienen que fallar en `hasError == false`, en `isIdle` y en el banner. El defecto estaba fijado
por un test en verde; un test nuevo que nunca se ha visto rojo no prueba que mire lo que dice
mirar.

Dos precisiones, para no fabricar un rojo:

- **Esperar `inFlightActivity` contra el código de hoy no vale como rojo.** Hoy es `nil`, el
  `await` vuelve al instante y el test fallaría por comprobar antes de tiempo, no por el
  defecto. El paso a `inFlightActivity` se hace en la misma tarea que cambia `login()`.
- **El test del segundo intento no tiene que estar rojo hoy.** A nivel de view model un
  segundo `.login` tras un fallo ya funcionaba: lo que impedía reintentar era la vista, que
  escondía el botón. Se añade como regresión —que un fallo no deje al view model rechazando el
  siguiente envío—, y así se dice en su tarea.

## Risks / Trade-offs

- **[Los tests que esperan `inFlightLoad` dejan de esperar]** → tras el cambio `inFlightLoad`
  es `nil` en esta pantalla, y un `await viewModel.inFlightLoad?.value` vuelve al instante sin
  fallar: el test comprobaría antes de que el login termine. Mitigación: los cuatro tests
  existentes pasan a `inFlightActivity` en la misma tarea que cambia `login()`, y un `grep`
  comprueba que no queda ningún `inFlightLoad` en el fichero.
- **[Los `XCUITests` no corren en local]** → es el límite escrito en los criterios; lo cierra
  el job `App` del CI.
- **[El banner se retira solo a los pocos segundos]** → el formulario sigue ahí, que es lo que
  importa; quien no llegó a leerlo ve el mismo mensaje al reenviar.
- **[Se pierde el título del error]** → decidido en la 1. Si el owner prefiere título y
  mensaje, la alternativa es `.alert` y cambia una palabra, pero cambia también el escenario
  de la spec.
