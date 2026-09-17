## MODIFIED Requirements

### Requirement: Un contrato que implementa un actor se declara nonisolated

Los dos paquetes se compilan con `defaultIsolation(MainActor)`, así que **todo lo que no se
anota queda aislado al MainActor**. Eso obliga a anotar en dos sitios, y este requisito cubre
los dos: los protocolos y los tipos.

**Protocolos.** Un protocolo sin anotación explícita queda aislado al MainActor y un `actor`
no puede conformarlo.

Todo protocolo `Sendable` de este repo que tenga —en producción o en tests— al menos un
conformante declarado como `actor` SHALL declararse `nonisolated`. Cuando ese protocolo
traiga implementaciones por defecto en una `extension`, la `extension` SHALL declararse
`nonisolated` también: sin eso, el aislamiento vuelve a entrar por los miembros heredados y
son los conformantes los que tienen que anotarse uno a uno.

Un protocolo cuyos conformantes son todos `@MainActor` SHALL NOT anotarse: marcarlo
`nonisolated` mueve el fallo al conformante en vez de resolverlo.

El incumplimiento no es una cuestión de estilo — rompe el build con `actor 'X' cannot
conform to global-actor-isolated protocol 'Y'`.

**Tipos.** Con `InferIsolatedConformances` activo, la conformidad de un tipo aislado se
infiere aislada también. Un tipo de este repo cuya conformidad se use fuera del MainActor
—un DTO que se serializa dentro de una petición, un error que se lanza desde código
`nonisolated`— SHALL declararse `nonisolated`.

Este incumplimiento es peor de detectar que el de los protocolos, y por eso se escribe aquí:
el diagnóstico es `main actor-isolated conformance of 'X' to 'Y' cannot be used in caller
isolation inheriting-isolated context [#IsolatedConformances]`, lo produce el toolchain del
CI y NO lo produce el de Xcode 27 (Swift 6.4) con los ajustes normales del paquete, así que la
verificación local firma en verde un fichero que el CI rechaza. Sí se reproduce en local
apagando `NonisolatedNonsendingByDefault` sobre el target afectado, que deja los `async` en
`nonisolated` completo — un chequeo más estricto que el del CI. La orden exacta, con lo que esa
sonda no cubre, está en el cambio que escribió este párrafo.

Qué exime de anotar, medido con el compilador: estar anidado dentro de un tipo ya
`nonisolated`, o dentro de un conformante de `BaseRequest` —el protocolo de CoreNetworking,
que es `Sendable` y viene de un módulo sin `defaultIsolation`—, que es donde viven los DTO de
petición de este repo. **El anidamiento por sí solo NO exime**: un tipo anidado dentro de otro
sin anotar falla igual, aunque el exterior sea `Sendable`.

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

#### Scenario: Se añade un DTO que se serializa en una petición

- **WHEN** se declara en el nivel de fichero de un target de `Packages/` un tipo
  `Encodable`/`Decodable` que un Service codifica o decodifica en una función `async` sin
  anotar
- **THEN** el tipo está declarado `nonisolated`
- **AND** el paquete compila con el toolchain del CI, no solo con el del Xcode instalado

#### Scenario: Se anota un contrato y no el tipo que ese contrato serializa

- **WHEN** un protocolo pasa a `nonisolated` y algún tipo que sus métodos codifican se queda
  sin anotar
- **THEN** el build falla con `[#IsolatedConformances]` en el toolchain del CI
- **AND** la verificación local con un toolchain más nuevo no lo detecta
