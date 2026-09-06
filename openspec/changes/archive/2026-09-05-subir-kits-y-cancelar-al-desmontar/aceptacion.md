# Aceptación — subir-kits-y-cancelar-al-desmontar

Ejecutado el 2026-09-05 siguiendo `.claude/agents/aceptacion.md`, contra el commit `4488c24`.

| criterio (del proposal) | veredicto | evidencia |
|---|---|---|
| Mover los tres lockfiles a AF 1.3.1 / CN 1.2.2 | **CUMPLIDO** | los tres `Package.resolved` en 1.3.1/1.2.2 |
| Adoptar `cancelsInFlightWorkOnRemoval` en las pantallas que lanzan trabajo largo | **NO VERIFICABLE** | «las pantallas que lanzan trabajo largo» no nombra ninguna: no hay forma de comprobar si están todas. Además el criterio quedó invertido al implementar (el default ya es `true`; el trabajo real era buscar dónde ponerlo en `false`) y el proposal nunca se actualizó |
| Nada más: sin refactors de paso | **NO CUMPLIDO** | ver abajo |
| FUERA DE ALCANCE: cambiar los rangos de los manifiestos | **VIOLADO** | `project.yml:31,34`, `Packages/Platform/Package.swift:32-33`, `Packages/Features/Package.swift:35-36` — se subió `from:` en los tres |

## VERDICT: ACUERDO-ROTO

## Qué pasó, exactamente

El cambio **compila, pasa 144 tests y hace lo que hacía falta**. Y aun así rompió su propio
acuerdo en dos sitios:

1. **Hizo lo que su «Fuera de alcance» prohibía.** Subir el `from:` de los tres manifiestos
   no estaba autorizado. Y no fue capricho: era **necesario** —el resolutor de Xcode se
   quedaba en 1.2.3 aunque el clon tuviera el tag 1.3.1—, pero eso es justamente el momento
   en que hay que **volver al acuerdo y renegociarlo por escrito**, no seguir adelante
   porque «es obvio que hace falta». Nadie se enteró hasta esta revisión.

2. **Un criterio escrito de forma incomprobable.** «Las pantallas que lanzan trabajo largo»
   no se puede verificar: no dice cuáles. Al implementar se descubrió que el criterio
   estaba del revés, se hizo lo correcto (`false` en Uploads) y **el proposal se quedó como
   estaba**. El acuerdo y el resultado divergieron sin que nadie lo declarara.

## Lo que esto demuestra

Ninguno de los dos fallos lo habría visto nada de lo que ya había: el compilador no opina
de alcance, los 144 tests pasan, `archlint` está verde, y un reviewer mirando el diff habría
dicho GREEN — porque el diff, en sí, es correcto.

Se ven **solo** comparando el resultado contra el acuerdo, al final, con la pregunta puesta.
Y los cometió un agente que había escrito ese acuerdo él mismo cuarenta minutos antes.

## Qué se hace con esto

Este cambio ya está commiteado y es correcto. No se revierte: se corrige el **acuerdo**,
que es lo que estaba mal — el `from:` de los manifiestos entra en alcance con su razón
escrita, y el criterio de las pantallas se sustituye por el que de verdad se cumplió.
Es la dirección legítima; la prohibida es la contraria (retocar el acuerdo para que encaje
sin decirlo).
