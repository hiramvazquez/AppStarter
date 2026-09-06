# plataforma Specification

## Purpose

Contrato de la capa de plataforma de AppStarter: qué garantizan los kits propios
(`AppFoundation`, `CoreNetworking`) a las features que los consumen, en las partes que
tienen comportamiento observable por el usuario.

Cubre solo lo verificado hasta hoy. Un requisito que no esté aquí no es que no exista: es
que nadie lo ha escrito todavía, y se añade cuando un cambio lo toque.

## Requirements

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
- **THEN** la petición se cancela
- **AND** `LoginView` se queda con el default del kit, sin pasar el parámetro

Decidido por el owner el 2026-09-05: **el login se cancela**. Un login sin pantalla no
tiene a quién entregarle el resultado — ni la sesión que lo pidió, ni el formulario que
recogería el error. Y a diferencia de la subida de Uploads, repetirlo es barato: el usuario
vuelve a la pantalla y lo intenta otra vez, sin haber perdido nada por el camino.

### Requirement: El usuario no ve errores internos

Un error envuelto (`WrappedError`) SHALL presentar al usuario únicamente el mensaje de la
capa que lo envuelve. El error interno SHALL quedar disponible para el log y el
diagnóstico, y SHALL NOT aparecer en pantalla.

#### Scenario: Un fallo de red envuelto por una capa de dominio

- **WHEN** una operación falla y el error se envuelve antes de llegar a la vista
- **THEN** el texto en pantalla es el de la capa que envuelve
- **AND** el error original no forma parte de ese texto

### Requirement: Versión mínima de los kits

Los manifiestos del proyecto SHALL declarar AppFoundation `1.3.1` o superior y
CoreNetworking `1.2.2` o superior, en los tres sitios donde vive el suelo de versión:
`project.yml`, `Packages/Platform/Package.swift` y `Packages/Features/Package.swift`.

Por debajo de esas versiones el proyecto arrastra un fallo de seguridad ya corregido
(AppFoundation 1.2.6, el error interno visible para el usuario).

#### Scenario: Se resuelve el grafo de dependencias

- **WHEN** se ejecuta `swift package update` o `xcodebuild -resolvePackageDependencies`
- **THEN** los tres `Package.resolved` quedan en AppFoundation 1.3.1 o superior
- **AND** en CoreNetworking 1.2.2 o superior
