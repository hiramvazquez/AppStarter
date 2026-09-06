# Subir los kits y cancelar el trabajo en vuelo al desmontar

## Intención

Los tres `Package.resolved` de este repo están clavados en **AppFoundation 1.2.3** y
**CoreNetworking 1.0.0**, aunque los manifiestos ya admiten cualquier 1.x. La app arrastra
por eso dos cosas que ya están resueltas aguas arriba:

1. **Un fallo de seguridad** (AppFoundation 1.2.6): `WrappedError` componía `screenError` y
   `message` enseñando el error INTERNO al usuario final.
2. **Una capacidad que esta app necesita** (AppFoundation 1.3.0):
   `ScreenContainer(cancelsInFlightWorkOnRemoval:)` + `ScreenState.cancelInFlightWork()`,
   que cancelan el trabajo en vuelo de una pantalla al eliminarla de la jerarquía —y NO al
   taparla con un push, que perdería la carga de la pantalla anterior al volver.

## Alcance

- Mover los tres lockfiles a AppFoundation **1.3.1** y CoreNetworking **1.2.2**.
- Subir el `from:` de los tres manifiestos (`project.yml` y los dos `Package.swift`).
  **Añadido tras la aceptación** (ver `aceptacion.md`): estaba fuera de alcance y resultó
  imprescindible — el resolutor de Xcode se quedaba en 1.2.3 aunque el clon tuviera el tag.
- Auditar `cancelsInFlightWorkOnRemoval`: el default es `true` desde 1.3.0, así que la tarea
  real es encontrar dónde ese default es el equivocado.
- Nada más: sin refactors de paso, sin tocar features que no lo necesiten.

## Criterios de aceptación

- [x] Los tres `Package.resolved` en AppFoundation 1.3.1 y CoreNetworking 1.2.2.
- [x] Los tres manifiestos con `from:` 1.3.1 / 1.2.2.
- [x] `UploadsFeature` pasa `cancelsInFlightWorkOnRemoval: false`, con la razón en el código.
- [x] Las otras 9 pantallas se quedan con el default.
- [x] `LoginFeature` queda anotado en la spec como decisión de producto pendiente.
- [x] Platform y Features: build y tests en verde. App: `xcodebuild build` y AppTests en verde.

## Fuera de alcance

- Migrar a las APIs nuevas de `load(_:)`/`activity(_:)` de 1.2.x — es otro cambio.

## Riesgo

CoreNetworking rompió API en **1.0.0**, versión que esta app ya usa: de 1.0.0 a 1.2.2 no
hay roturas declaradas en su changelog. El riesgo real es de compilación, no de contrato, y
lo cubre el paso de verificación.
