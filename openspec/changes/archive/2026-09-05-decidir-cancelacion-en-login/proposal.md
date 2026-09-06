# Decidir si el login se cancela al salir de su pantalla

## Contexto

AppFoundation 1.3.0 puso `cancelsInFlightWorkOnRemoval` a `true` por defecto, así que hoy
un login en vuelo se cancela si la pantalla desaparece de la jerarquía. Al subir la versión
se auditaron las diez pantallas y solo `UploadsView` se excluyó, porque su trabajo es una
subida con barra de progreso.

`LoginFeature` es el otro envío de formulario del repo
(`LoginViewModel.swift:67-69`, `try await logic.login(username:password:)`). Se quedó con
el default **sin decidirlo**: no porque se evaluara y se aprobara, sino porque no le tocaba
decidirlo a quien subía una dependencia. Este cambio existe para cerrar esa decisión, no
para dejarla escrita otra vez.

## La decisión

¿Un login en vuelo debe sobrevivir a que su pantalla desaparezca?

- **Cancelar (default actual).** El usuario se fue de la pantalla: la sesión que estaba
  pidiendo ya no la quiere. Y una petición de red que muere sola no deja estado a medias.
- **Sobrevivir.** Si la pantalla se destruye por un motivo que no es el usuario —un deep
  link, una recomposición, un cambio de pestaña— el login se pierde en silencio y el
  usuario ve un formulario vacío sin saber por qué.

Lo que decida el owner se escribe en la spec **con su razón**, para que el próximo que
mire no vuelva a preguntárselo.

## Alcance

- `Packages/Features/Sources/LoginFeature/LoginView.swift` — el flag, si se decide cambiarlo.
- `openspec/specs/plataforma/spec.md` — el escenario, en cualquiera de los dos casos.

## Fuera de alcance

- Las otras nueve pantallas. Ya se auditaron al subir la versión.
- Cambiar el default del kit. Eso es un cambio de AppFoundation, no de esta app.

## Criterios de aceptación

- [ ] La spec de `plataforma` tiene un escenario que dice qué le pasa a un login en vuelo
      cuando su pantalla se elimina, con la razón de la decisión escrita.
- [ ] `LoginView.swift` es coherente con ese escenario: si se decide sobrevivir, pasa
      `cancelsInFlightWorkOnRemoval: false` con la razón en un comentario; si se decide
      cancelar, se queda sin el parámetro y la razón vive en la spec.
- [ ] `bash Scripts/verifica.sh` en verde.
