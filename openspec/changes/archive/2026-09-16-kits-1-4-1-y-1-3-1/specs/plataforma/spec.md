## MODIFIED Requirements

### Requirement: Versión mínima de los kits

Los manifiestos del proyecto SHALL declarar AppFoundation `1.4.1` o superior y
CoreNetworking `1.3.1` o superior, en los tres sitios donde vive el suelo de versión:
`project.yml`, `Packages/Platform/Package.swift` y `Packages/Features/Package.swift`.

Por debajo de esas versiones el proyecto arrastra un fallo de seguridad ya corregido
(AppFoundation 1.2.6, el error interno visible para el usuario).

Por debajo de AppFoundation `1.3.2` el proyecto además no compila con un toolchain Swift
6.4 o superior: `DomainError` queda aislado al MainActor y ningún tipo de error de dominio
puede conformarlo desde código `nonisolated`.

#### Scenario: Se resuelve el grafo de dependencias

- **WHEN** se ejecuta `swift package update` o `xcodebuild -resolvePackageDependencies`
- **THEN** los tres `Package.resolved` quedan en AppFoundation 1.4.1 o superior
- **AND** en CoreNetworking 1.3.1 o superior

#### Scenario: Se compila con un toolchain Swift 6.4 o superior

- **WHEN** se construye cualquiera de los dos paquetes con el toolchain que trae el Xcode
  que resuelve el SDK
- **THEN** ningún tipo que conforma `DomainError` falla con `conformance ... crosses into
  main actor-isolated code`
- **AND** ningún tipo de error de dominio del repo necesita anotarse para conseguirlo
