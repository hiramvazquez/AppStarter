## MODIFIED Requirements

### Requirement: Versión mínima de los kits

Los manifiestos del proyecto SHALL declarar AppFoundation `1.3.2` o superior y
CoreNetworking `1.2.2` o superior, en los tres sitios donde vive el suelo de versión:
`project.yml`, `Packages/Platform/Package.swift` y `Packages/Features/Package.swift`.

Por debajo de esas versiones el proyecto arrastra un fallo de seguridad ya corregido
(AppFoundation 1.2.6, el error interno visible para el usuario).

Por debajo de AppFoundation `1.3.2` el proyecto además no compila con un toolchain Swift
6.4 o superior: `DomainError` queda aislado al MainActor y ningún tipo de error de dominio
puede conformarlo desde código `nonisolated`.

#### Scenario: Se resuelve el grafo de dependencias

- **WHEN** se ejecuta `swift package update` o `xcodebuild -resolvePackageDependencies`
- **THEN** los tres `Package.resolved` quedan en AppFoundation 1.3.2 o superior
- **AND** en CoreNetworking 1.2.2 o superior

#### Scenario: Se compila con un toolchain Swift 6.4 o superior

- **WHEN** se construye cualquiera de los dos paquetes con el toolchain que trae el Xcode
  que resuelve el SDK
- **THEN** ningún tipo que conforma `DomainError` falla con `conformance ... crosses into
  main actor-isolated code`
- **AND** ningún tipo de error de dominio del repo necesita anotarse para conseguirlo

## ADDED Requirements

### Requirement: Un contrato que implementa un actor se declara nonisolated

Los dos paquetes se compilan con `defaultIsolation(MainActor)`, así que un protocolo sin
anotación explícita queda aislado al MainActor y un `actor` no puede conformarlo.

Todo protocolo `Sendable` de este repo que tenga —en producción o en tests— al menos un
conformante declarado como `actor` SHALL declararse `nonisolated`. Cuando ese protocolo
traiga implementaciones por defecto en una `extension`, la `extension` SHALL declararse
`nonisolated` también: sin eso, el aislamiento vuelve a entrar por los miembros heredados y
son los conformantes los que tienen que anotarse uno a uno.

Un protocolo cuyos conformantes son todos `@MainActor` SHALL NOT anotarse: marcarlo
`nonisolated` mueve el fallo al conformante en vez de resolverlo.

El incumplimiento no es una cuestión de estilo — rompe el build con `actor 'X' cannot
conform to global-actor-isolated protocol 'Y'`.

#### Scenario: Se añade un Store o Service implementado como actor

- **WHEN** se escribe un `*Storing`/`*Servicing` cuya implementación o cuyo doble de test es
  un `actor`
- **THEN** el protocolo está declarado `nonisolated`
- **AND** los dos paquetes compilan sin que el `actor` necesite dejar de serlo

#### Scenario: El protocolo trae implementaciones por defecto

- **WHEN** un protocolo `nonisolated` de este repo aporta implementaciones por defecto en una
  `extension`
- **THEN** esa `extension` también está declarada `nonisolated`
- **AND** sus conformantes compilan sin anotación propia

#### Scenario: Todos los conformantes viven en el MainActor

- **WHEN** el único conformante de un protocolo es un tipo `@MainActor` que toca estado de UI
- **THEN** el protocolo se queda sin anotar
- **AND** el build sigue en verde

### Requirement: El toolchain con el que se construye el proyecto está documentado

`AGENTS.md` SHALL decir que el proyecto se construye con el toolchain que trae el Xcode
instalado, y SHALL recoger el síntoma de usar otro distinto.

Un toolchain de swift.org más antiguo que el de Xcode —el que deja en el PATH un gestor
como swiftly— falla con `unknown argument: '-target-arch-variant'` y con
`build planning stopped due to build-tool plugin failures`. Ninguno de los dos mensajes
menciona el toolchain, así que sin documentarlo el fallo se diagnostica como un problema del
código del repo, que es lo que pasó al actualizar a Xcode 27.

#### Scenario: Alguien clona el repo con otro toolchain en el PATH

- **WHEN** se ejecuta `swift build` y el build muere en `build-tool plugin failures`
- **THEN** `AGENTS.md` permite identificar el toolchain como la causa
- **AND** dice cómo seleccionar el de Xcode
