# Los fixtures de snapshot leen ErrorCopy

## Why

`ErrorCopy` centralizó los textos de error de las nueve features, pero cuatro fixtures de
snapshot siguen escribiéndolos a mano: `DiagnosticsSnapshotTests` y
`UploadsSnapshotTests` (dos sitios cada uno). No incumplen la spec —son fixtures que llaman a
`vm.setError(...)`, no pantallas— pero son cuatro sitios donde el texto puede quedarse atrás
del canónico sin que nada avise, y la imagen de referencia diría que todo está bien.

## What Changes

- Los cuatro `vm.setError(...)` usan `ErrorCopy.Unknown` y `ErrorCopy.Server`, con
  `import Domain` en los dos ficheros. `AppSnapshotTests` ya depende del producto `Domain`
  (`project.yml:180-181`).
- **`kit.conf` pasa a verificar la app**, y esto NO estaba en el acuerdo original. Se
  descubrió implementando: `kit-verifica` solo corría `swift build`/`swift test` de los dos
  paquetes, así que **nada compilaba `AppSnapshotTests`** — los ficheros que este cambio
  toca. Comprobado con un experimento: metiendo texto que ni siquiera es Swift válido en
  `UploadsSnapshotTests.swift`, la verificación firmaba **VERDE**.
  Entra en alcance porque sin ello este cambio no se puede verificar en absoluto: la firma
  cubriría todo menos lo único que toca. Cuesta ~1 min más por verificación.

## Fuera de alcance

- Regenerar imágenes de referencia: el texto no cambia, así que no deben cambiar.
- Los demás fixtures de snapshot, que usan textos propios y no canónicos.

## Criterios de aceptación

- [ ] Los cuatro sitios usan `ErrorCopy`; `grep 'setError(title: "'` sobre `AppSnapshotTests`
      no encuentra ninguno de los cuatro literales canónicos.
- [ ] Las imágenes de referencia **no cambian**: el texto renderizado es el mismo.
- [ ] `/kit-verifica` en verde, **y su informe incluye el paso de la app**.
- [ ] Con un fichero de `AppSnapshotTests` roto a propósito, `/kit-verifica` sale en ROJO y
      no firma. (Comprobado en los dos sentidos antes de entregar.)
