# Aceptación — unificar-textos-de-error-comunes

Cuatro rondas con sub-agentes reales (`reviewer` y `aceptacion`, contexto fresco cada vez).

| ronda | reviewer | juez | qué encontraron |
|---|---|---|---|
| 1 | **RED** | **DEVUELTO** | criterio inalcanzable; spec universal incumplida por 7 features; árbol sucio |
| 2 | **AMBER** | **ACUERDO-ROTO** | C2 contradecía al «Fuera de alcance» del mismo documento; C4 decía nueve pantallas cuando eran siete; el par «No encontrado» seguía duplicado |
| 3 | — | **ACUERDO-ROTO** | C3 decía «ocho pantallas» cuando son siete, **y el número estaba escrito en un comentario del código**; «tres pares» cuando son cuatro; «seis literales» cuando son ocho |
| 4 | — | **ACEPTADO** | todos los números recontados con comandos; ningún NO CUMPLIDO |

## El hallazgo que cambió la decisión

El reviewer de la ronda 1 no dijo «falta migrar siete features». Dijo que así entregado era
**peor que no hacer el cambio**, y lo demostró: antes había un mecanismo —literales por
todas partes— y quien tocaba uno sabía que tocaba uno; después había dos, y quien editara la
constante creería razonablemente haber cambiado el texto de toda la app. Una fuente de
verdad que no gobierna al 78% de sus consumidores es una trampa.

Eso reclasificó el trabajo de *incompleto* a *dañino*, y con ello la decisión: se completó
la migración a las nueve features en vez de acotar la spec a lo entregado, que era el atajo
cómodo.

Y la prueba de que el riesgo no era teórico: `DiagnosticsModels.swift` llevaba tiempo
diciendo «Inténtalo de nuevo.» donde el resto decía «Inténtalo de nuevo más tarde.» para el
mismo error. La deriva que este cambio existe para impedir **ya había ocurrido**.

## Lo que costó, y a quién

De la ronda 2 en adelante **ninguna vuelta fue por el código**: fueron por números mal
contados en el propio acuerdo — nueve pantallas que eran siete, tres pares que eran cuatro,
seis literales que eran ocho. Cada corrección introducía otra imprecisión, porque parchear
un documento largo es justo cómo se introducen.

De ahí salió el tope de dos rondas que ahora lleva escrito `.claude/agents/aceptacion.md`
del kit, y el aviso sobre criterios que cuentan cosas. El juez de la ronda 4 leyó ese tope
recién puesto y lo aplicó a sí mismo antes de aceptar.

## Corregido tras el ACEPTADO

El juez dejó una observación fuera del veredicto: el «siete» había quedado escrito en un
comentario permanente de `DiagnosticsModels.swift`, y el proposal se archiva pero el
comentario se queda — la décima pantalla con `.server` lo dejaría mintiendo. Se le quitó el
número. Es la misma lección que el propio cambio existe para enseñar, aplicada a sí mismo.

## VERDICT: ACEPTADO
