## ADDED Requirements

### Requirement: Los tests de la app corren con un locale fijado

Los tests de la app SHALL ejecutarse con un idioma y una región fijados por el proyecto, de
modo que el locale que ve el proceso de test sea el mismo en cualquier máquina, tenga el
locale de sistema que tenga. El locale fijado es `en_US`.

Una referencia de snapshot SHALL NOT depender del locale de la máquina que la graba ni del de
la que la compara. Una pantalla que pinta texto formateado según el locale —un importe, una
fecha, un número— es la que lo destapa: `US$540.00` en una máquina y `$540.00` en otra son la
misma pantalla y dos fotos distintas, y el fallo que produce («does not match reference») no
nombra el locale.

Lo que se fija es el entorno del test. Cómo formatea la app para el usuario no cambia: una
pantalla que respeta el locale del dispositivo sigue respetándolo.

#### Scenario: Los tests corren en una máquina con otro locale de sistema

- **WHEN** los tests de la app se ejecutan en una máquina cuyo locale de sistema no es `en_US`
- **THEN** el proceso de test ve `en_US`
- **AND** un importe formateado con el locale del proceso sale igual que en cualquier otra
  máquina

#### Scenario: Se graba la referencia de una pantalla con texto que depende del locale

- **WHEN** se graba la referencia de un snapshot cuya pantalla pinta importes, fechas o números
  formateados
- **THEN** la referencia se graba con el locale fijado
- **AND** el mismo test pasa en una máquina con otro locale de sistema sin regrabar nada

#### Scenario: Se cambia el locale fijado

- **WHEN** un cambio sustituye `en_US` por otro locale
- **THEN** ese mismo cambio regraba las referencias cuyo texto depende del locale
