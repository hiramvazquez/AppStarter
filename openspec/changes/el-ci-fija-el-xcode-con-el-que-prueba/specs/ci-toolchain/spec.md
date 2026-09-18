## Purpose

Fija con qué versión de toolchain se mide este repositorio en la integración continua, de
forma que esa versión no pueda cambiar sin que alguien lo decida, y que una incompatibilidad
con el toolchain de desarrollo se vea en el CI y no al publicar.

## ADDED Requirements

### Requirement: La versión del toolchain del CI es explícita

La integración continua MUST nombrar la versión de Xcode que usa. Esa versión MUST estar
escrita en un solo sitio del que la lean todos los jobs, y NOT MUST resolverse a partir de lo
que la imagen del runner tenga instalado —por ejemplo, ordenando `/Applications/Xcode_*.app` y
tomando la última—, porque esa resolución cambia cuando la imagen se actualiza y desplazaría
la versión validada sin intervención humana.

Junto a la versión MUST constar la fecha en que se comprobó qué ofrece la imagen y el comando
que lo comprueba, para que subirla exija rehacer la medición.

#### Scenario: La imagen del runner incorpora una versión mayor

- **WHEN** la imagen del runner añade una versión de Xcode superior a la que el CI venía
  usando
- **THEN** el CI sigue validando exactamente la versión que tiene escrita
- **AND** adoptar la nueva exige un cambio explícito en el repositorio

#### Scenario: Alguien quiere saber contra qué versión está verde `main`

- **WHEN** se lee la definición del CI
- **THEN** la versión aparece nombrada, no derivada de una expresión que haya que evaluar
- **AND** aparecen junto a ella la fecha de la comprobación y el comando que la sustenta

#### Scenario: Un job de macOS se añade más adelante

- **WHEN** se añade un job nuevo que compila o prueba el proyecto en macOS
- **THEN** selecciona el toolchain leyendo la misma versión declarada que los demás
- **AND** no declara una versión propia

### Requirement: El toolchain de desarrollo tiene aviso temprano

La integración continua MUST ejercitar también el toolchain con el que se desarrolla el
proyecto, cuando sea posterior al que valida, para que una incompatibilidad con él se vea en
el CI y no al abrir Xcode. Ese ejercicio NOT MUST bloquear la corrida mientras ese toolchain
solo esté disponible en una imagen en preview o en una versión beta.

La definición del CI MUST dejar escrita la condición concreta que convierte ese job en
bloqueante.

#### Scenario: Un cambio rompe el toolchain de desarrollo

- **WHEN** un cambio compila con la versión que el CI valida pero no con el toolchain de
  desarrollo
- **THEN** la corrida lo señala en un job identificable como aviso temprano
- **AND** la corrida no se marca como fallida solo por ese job

#### Scenario: El aviso temprano se vuelve exigible

- **WHEN** la imagen que da el toolchain de desarrollo deja de estar en preview y su Xcode es
  estable
- **THEN** la condición para convertir ese job en bloqueante está escrita en el repositorio

### Requirement: La versión validada resiste ser más estricta que la de desarrollo

La versión que el CI valida de forma bloqueante MUST ser la que decida el owner, y MUST
seguir siéndolo aunque el toolchain de desarrollo acepte código que ella rechaza. Un
diagnóstico que solo emite la versión del CI es motivo para corregir el código, NOT MUST
serlo para subir la versión del CI hasta que deje de emitirse.

Esta es la situación real de este repositorio y no una hipótesis: medido el 2026-09-17, el
diagnóstico `[#IsolatedConformances]` sobre una conformidad inferida como aislada al MainActor
es error en Swift 6.2.4 y en 6.3.3, y no lo es en 6.4, pese a que 6.4 sigue infiriendo esa
conformidad como aislada.

#### Scenario: El CI rechaza código que compila en la máquina de quien lo escribió

- **WHEN** un job bloqueante falla con un diagnóstico que el toolchain de desarrollo no emite
- **THEN** se corrige el código para que compile en ambas versiones
- **AND** subir la versión del CI para silenciarlo exige una decisión escrita del owner, no
  es la respuesta por defecto
