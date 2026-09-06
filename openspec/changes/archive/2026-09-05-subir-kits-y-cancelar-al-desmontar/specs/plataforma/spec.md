# Delta — plataforma

## AÑADIDO: cancelación del trabajo en vuelo al desmontar una pantalla

Una pantalla que lanza trabajo asíncrono **cancela ese trabajo cuando se la elimina de la
jerarquía de navegación** (pop, cambio de pestaña que destruye la vista, dismiss de un
modal).

**No lo cancela cuando la pantalla queda simplemente TAPADA** por un push: al volver, su
carga sigue siendo válida y no debe repetirse.

Se expresa con `ScreenContainer(viewModel, cancelsInFlightWorkOnRemoval:)`, que **viene a
`true` por defecto** desde AppFoundation 1.3.0: subir la version ya cambia el
comportamiento de las 10 pantallas sin tocar una linea. El kit expone tambien
`ScreenState.cancelInFlightWork()` para el caso manual.

### EXCEPCION: el trabajo que debe sobrevivir a su pantalla

**Uploads** pasa `cancelsInFlightWorkOnRemoval: false`. Su trabajo en vuelo es una subida
de foto con barra de progreso, y perderla porque el usuario navego fuera es peor que el
problema que el default resuelve.

**Pendiente de decision del owner:** `LoginFeature` es el otro envio de formulario del
repo. Cancelar un login al salir de la pantalla es probablemente correcto —el usuario se
fue—, pero es una decision de producto, no del que sube la dependencia. Se deja con el
default `true` y anotado aqui.

## MODIFICADO: qué ve el usuario cuando un error se envuelve

Un error envuelto (`WrappedError`) presenta al usuario **solo** el mensaje de la capa que
lo envuelve. El error interno queda para el log y para diagnóstico, nunca en pantalla.

Antes: `screenError` y `message` componían el texto con el error interno incluido.

## Versiones mínimas

| kit | antes | ahora |
|---|---|---|
| AppFoundation | 1.2.3 | **1.3.1** |
| CoreNetworking | 1.0.0 | **1.2.2** |
