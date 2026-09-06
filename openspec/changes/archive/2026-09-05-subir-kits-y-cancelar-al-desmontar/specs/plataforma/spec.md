## ADDED Requirements

### Requirement: Cancelación del trabajo en vuelo al desmontar una pantalla

Una pantalla montada con `ScreenContainer` SHALL cancelar su trabajo asíncrono en vuelo
cuando la vista sea eliminada de la jerarquía de navegación, y SHALL NOT cancelarlo cuando
la vista quede únicamente cubierta por otra empujada encima.

El comportamiento se controla con `ScreenContainer(_:cancelsInFlightWorkOnRemoval:)`, cuyo
valor por defecto es `true` desde AppFoundation 1.3.0: subir la versión cambia el
comportamiento de las diez pantallas sin tocar una línea.

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

### Requirement: Versión mínima de los kits

Los manifiestos del proyecto SHALL declarar AppFoundation `1.3.1` o superior y
CoreNetworking `1.2.2` o superior, en los tres sitios donde vive el suelo de versión:
`project.yml`, `Packages/Platform/Package.swift` y `Packages/Features/Package.swift`.

#### Scenario: Se resuelve el grafo de dependencias

- **WHEN** se ejecuta `swift package update` o `xcodebuild -resolvePackageDependencies`
- **THEN** los tres `Package.resolved` quedan en AppFoundation 1.3.1 o superior
- **AND** en CoreNetworking 1.2.2 o superior

## MODIFIED Requirements

### Requirement: El usuario no ve errores internos

Un error envuelto (`WrappedError`) SHALL presentar al usuario únicamente el mensaje de la
capa que lo envuelve. El error interno SHALL quedar disponible para el log y el
diagnóstico, y SHALL NOT aparecer en pantalla.

Antes de AppFoundation 1.2.6, `screenError` y `message` componían el texto incluyendo el
error interno. Era un fallo de seguridad y por eso este requisito cambia de comportamiento
al subir la versión, no de redacción.

#### Scenario: Un fallo de red envuelto por una capa de dominio

- **WHEN** una operación falla y el error se envuelve antes de llegar a la vista
- **THEN** el texto en pantalla es el de la capa que envuelve
- **AND** el error original no forma parte de ese texto
