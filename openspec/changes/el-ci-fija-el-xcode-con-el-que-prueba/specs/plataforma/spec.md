## MODIFIED Requirements

### Requirement: El toolchain con el que se construye el proyecto está documentado

`AGENTS.md` SHALL decir que el proyecto se construye con el toolchain que trae el Xcode
instalado, y SHALL recoger el síntoma de usar otro distinto. SHALL decir también con qué
versión de Xcode valida el CI y, cuando no sea la misma, que una verificación local no cubre
la compatibilidad con ella.

Un toolchain de swift.org más antiguo que el de Xcode —el que deja en el PATH un gestor
como swiftly— falla con `unknown argument: '-target-arch-variant'` y con
`build planning stopped due to build-tool plugin failures`. Ninguno de los dos mensajes
menciona el toolchain, así que sin documentarlo el fallo se diagnostica como un problema del
código del repo, que es lo que pasó al actualizar a Xcode 27.

El desfase con el CI es la otra mitad del mismo problema, y muerde en sentido contrario: el
toolchain de desarrollo (Xcode 27 / Swift 6.4) **acepta** código que el del CI rechaza. Medido
el 2026-09-17, el diagnóstico `[#IsolatedConformances]` sobre una conformidad inferida como
aislada al MainActor es error en Swift 6.2.4 y en 6.3.3, y no lo es en 6.4. Por eso una
verificación local en verde —`/kit-verifica` incluido— no es prueba de que el CI vaya a pasar,
y quien lo ignore diagnosticará el rojo como un problema del CI en vez de como lo que es.

#### Scenario: Alguien clona el repo con otro toolchain en el PATH

- **WHEN** se ejecuta `swift build` y el build muere en `build-tool plugin failures`
- **THEN** `AGENTS.md` permite identificar el toolchain como la causa
- **AND** dice cómo seleccionar el de Xcode

#### Scenario: Alguien va a confiar en una verificación local antes de publicar

- **WHEN** una persona o un agente verifica el repositorio en su máquina y sale en verde
- **THEN** `AGENTS.md` le dice con qué versión de Xcode valida el CI
- **AND** le advierte de que su verificación no cubre la compatibilidad con esa versión
