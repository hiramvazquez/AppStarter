# inicio-de-sesion Specification

## Purpose

Entrar en la app con usuario y contraseña, y lo que le queda al usuario en la mano cuando el
intento no sale: el formulario, lo que tecleó y un mensaje que le dice qué corregir. Qué
credenciales son válidas lo decide el servidor, no esta capacidad.

## Requirements

### Requirement: Un inicio de sesión que falla deja el formulario a la vista

Cuando un intento de iniciar sesión no sale —el servidor rechaza las credenciales, no hay red,
el servidor falla o falta un campo—, la pantalla SHALL seguir mostrando el formulario con el
usuario tecleado, SHALL enseñar el mensaje del error sin sustituir el formulario, y SHALL
permitir otro intento sin salir de la pantalla ni relanzar la app.

#### Scenario: El servidor rechaza las credenciales

- **WHEN** el usuario envía el formulario y el servidor rechaza usuario y contraseña
- **THEN** el formulario sigue visible con el usuario que se tecleó
- **AND** se muestra el mensaje «Comprueba tu usuario y contraseña.»
- **AND** la app sigue en la pantalla de inicio de sesión

#### Scenario: Segundo intento tras un fallo

- **WHEN** tras un intento fallido el usuario corrige lo tecleado y vuelve a enviar con
  credenciales que el servidor acepta
- **THEN** entra en el catálogo
- **AND** no ha tenido que salir de la pantalla ni relanzar la app

#### Scenario: Falta un campo

- **WHEN** el usuario envía el formulario con el usuario o la contraseña vacíos
- **THEN** el formulario sigue visible
- **AND** se muestra qué campo falta

#### Scenario: Sin conexión

- **WHEN** el envío falla porque no hay red
- **THEN** el formulario sigue visible con el usuario que se tecleó
- **AND** se muestra el mensaje de falta de conexión
- **AND** el usuario puede reenviar con el mismo botón

### Requirement: Un inicio de sesión correcto entra en el catálogo

Cuando el servidor acepta las credenciales, la app SHALL dejar la pantalla de inicio de sesión
y mostrar el catálogo como raíz de la navegación.

#### Scenario: El servidor acepta las credenciales

- **WHEN** el usuario envía el formulario y el servidor acepta usuario y contraseña
- **THEN** la raíz de la navegación pasa a ser el catálogo
- **AND** la pantalla de inicio de sesión deja de mostrarse
