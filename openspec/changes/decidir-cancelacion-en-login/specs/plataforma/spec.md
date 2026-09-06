## MODIFIED Requirements

### Requirement: Cancelación del trabajo en vuelo al desmontar una pantalla

Una pantalla montada con `ScreenContainer` SHALL cancelar su trabajo asíncrono en vuelo
cuando la vista sea eliminada de la jerarquía de navegación, y SHALL NOT cancelarlo cuando
la vista quede únicamente cubierta por otra empujada encima.

El comportamiento se controla con `ScreenContainer(_:cancelsInFlightWorkOnRemoval:)`, cuyo
valor por defecto es `true` desde AppFoundation 1.3.0.

Cada pantalla que se aparte del default SHALL declarar por qué en el propio código.

#### Scenario: La pantalla se elimina de la jerarquía

- **WHEN** el usuario hace pop de una pantalla que tiene una carga en curso
- **THEN** el trabajo en vuelo se cancela
- **AND** no se entrega ningún resultado a una vista que ya no existe

#### Scenario: La pantalla queda cubierta por un push

- **WHEN** el usuario empuja otra pantalla encima de una que tiene una carga en curso
- **THEN** el trabajo en vuelo continúa
- **AND** al volver atrás la carga sigue siendo válida y no se repite

#### Scenario: El trabajo debe sobrevivir a su pantalla

- **WHEN** la pantalla es `UploadsView`, que sube una foto con barra de progreso
- **THEN** pasa `cancelsInFlightWorkOnRemoval: false`
- **AND** la subida continúa aunque el usuario navegue fuera

#### Scenario: Un login en vuelo pierde su pantalla

- **WHEN** `LoginView` tiene una petición de login en curso y su vista se elimina
- **THEN** <PENDIENTE: lo decide el owner — ver proposal.md>
