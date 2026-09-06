# Cómo se trabaja aquí

Convención [OpenSpec](https://github.com/Fission-AI/OpenSpec): la especificación vive en el
repo y se acuerda ANTES de escribir código. Brownfield-first — cada cambio se describe como
**delta** sobre lo que ya hay, no reescribiendo la spec entera.

## Estructura

```
openspec/
├── specs/<dominio>/spec.md          # verdad actual del sistema
└── changes/<nombre>/                # trabajo en curso (UNO a la vez)
    ├── proposal.md                  # intención, alcance, FUERA de alcance, criterios
    ├── tasks.md                     # checklist ejecutable
    └── specs/<dominio>/spec.md      # el DELTA: solo lo que cambia
└── changes/archive/<fecha>-<nombre>/
```

## El bucle

1. **Proponer** — `changes/<nombre>/` con proposal, tareas y delta. **Cero código.**
   El proposal lleva **criterios de aceptación verificables** (ver abajo).
2. **Implementar** — se ejecutan las tareas marcando `[x]`. Si cambia el entendimiento, se
   actualiza el artefacto; nunca se improvisa en silencio.
3. **Verificar** — `Scripts/verifica.sh`. Build, tests y lógica repetida, con el resultado
   **firmado contra el diff staged**. Sin firma válida no se commitea.
4. **Revisar** — sub-agente `reviewer`: ¿esto rompe algo? Contexto fresco, solo el diff.
5. **Aceptar** — sub-agente `aceptacion`: ¿es lo acordado? Criterio por criterio, con
   evidencia. Es el paso que caza el requisito que se evaporó por el camino.
6. **Archivar** — el delta se funde en `specs/` y la carpeta se mueve a `archive/`.

Los pasos 4 y 5 son distintos a propósito: un cambio puede estar impecable —arquitectura,
tests, lint— y **no ser lo que se pidió**. El reviewer no lo ve, porque no es su pregunta.

## Criterios de aceptación

Cada proposal termina con una lista de criterios que se puedan **comprobar mirando el
resultado**, no leyendo intenciones:

```markdown
## Criterios de aceptación

- [ ] `UploadsView` pasa `cancelsInFlightWorkOnRemoval: false` y hay un test que lo fija.
- [ ] Las otras 9 pantallas se quedan con el default `true`.
- [ ] `swift test` verde en Platform y Features.
```

Un criterio que no se pueda comprobar (**"la carga es más fluida"**) no es un criterio: el
juez de aceptación lo devuelve como ACUERDO-ROTO, y se reescribe antes de aprobar.

## Reglas de tamaño

- Un cambio = **4 ficheros como mucho**. Si necesita dos carpetas, son dos cambios.
- El delta describe lo que cambia; nunca repite la spec entera.
- El *por qué se hizo así* va al mensaje de commit. Aquí va lo que el sistema **hace**.

## La regla que impide que esto crezca

La tentación, en cuanto algo se escapa, es **hacer la lista de todo lo que hay que
vigilar** y escribir un detector por línea. Esa lista es infinita, y es literalmente cómo
un workflow anterior de esta casa llegó a 36.740 líneas en nueve semanas para vigilar 140
de producto. No se hace. En su lugar, cada cosa que se escapa se clasifica:

| ¿quién podía haberlo visto? | dónde va |
|---|---|
| El compilador, SwiftLint o `archlint` | ya está cubierto. No se añade nada. |
| Es mecánico y ningún linter lo ve | detector propio — **solo si ya falló DOS veces** |
| Solo se ve leyendo con criterio | **se mejora la pregunta del reviewer o del juez**, no se escribe código |

Y el orden importa: **primero se mejora la pregunta, después se escribe el detector.**
Cambiar una línea del prompt del revisor cuesta una línea. Un detector cuesta un script, su
test, y su mantenimiento para siempre.

Hoy hay **un solo** detector propio (`Scripts/busca-duplicados.py`) y está porque la clase
ya mordió tres veces: tres `extension Date` en tres view models distintos.
