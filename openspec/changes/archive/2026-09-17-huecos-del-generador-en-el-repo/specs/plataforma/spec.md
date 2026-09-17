## MODIFIED Requirements

### Requirement: Versión mínima de los kits

Los manifiestos del proyecto SHALL declarar AppFoundation `1.4.2` o superior y
CoreNetworking `1.3.1` o superior, en los tres sitios donde vive el suelo de versión:
`project.yml`, `Packages/Platform/Package.swift` y `Packages/Features/Package.swift`.

Por debajo de esas versiones el proyecto arrastra un fallo de seguridad ya corregido
(AppFoundation 1.2.6, el error interno visible para el usuario).

Por debajo de AppFoundation `1.3.2` el proyecto además no compila con un toolchain Swift
6.4 o superior: `DomainError` queda aislado al MainActor y ningún tipo de error de dominio
puede conformarlo desde código `nonisolated`.

Por debajo de AppFoundation `1.4.2`, `generate-feature` en modo multi deja este repo sin
compilar o con un formato que CI rechaza: inserta el módulo nuevo en `App/AppModule.swift`
sin poner la coma que necesita el último elemento de la lista, y genera ficheros que no
pasan `swift format lint --strict`.

#### Scenario: Se resuelve el grafo de dependencias

- **WHEN** se ejecuta `swift package update` o `xcodebuild -resolvePackageDependencies`
- **THEN** los tres `Package.resolved` quedan en AppFoundation 1.4.2 o superior
- **AND** en CoreNetworking 1.3.1 o superior

#### Scenario: Se compila con un toolchain Swift 6.4 o superior

- **WHEN** se construye cualquiera de los dos paquetes con el toolchain que trae el Xcode
  que resuelve el SDK
- **THEN** ningún tipo que conforma `DomainError` falla con `conformance ... crosses into
  main actor-isolated code`
- **AND** ningún tipo de error de dominio del repo necesita anotarse para conseguirlo

#### Scenario: Se genera una feature en modo multi

- **WHEN** se ejecuta `generate-feature` desde `Packages/Features` y se añade a mano solo el
  `case` de la ruta nueva en `AppRoute`
- **THEN** la lista de módulos de `App/AppModule.swift` sigue siendo Swift válido sin
  retocarla
- **AND** `swift format lint --strict` con la orden de CI sale limpio sobre lo generado, sin
  formatearlo a mano
