# OpenSpec — cómo se trabaja aquí

Convención [OpenSpec](https://github.com/Fission-AI/OpenSpec): la especificación vive en el
repo y es lo que se acuerda ANTES de escribir código. Brownfield-first — cada cambio se
describe como **delta** sobre lo que ya hay, no reescribiendo la spec entera.

## Estructura

```
openspec/
├── specs/<dominio>/spec.md     # verdad actual del sistema, por dominio
└── changes/<nombre>/           # trabajo en curso
    ├── proposal.md             # intención, alcance, enfoque
    ├── design.md               # decisiones técnicas (solo si el cambio las tiene)
    ├── tasks.md                # checklist ejecutable
    └── specs/<dominio>/spec.md # el DELTA: solo lo que cambia
└── changes/archive/<fecha>-<nombre>/
```

## El bucle

1. **propose** — se crea `changes/<nombre>/` con proposal + tasks (+ design si hace falta)
   y el delta de spec. **Nada de código todavía.**
2. **apply** — se ejecutan las tareas, marcando `[x]` según caen. Si al implementar cambia
   el entendimiento, se actualiza el artefacto, no se improvisa en silencio.
3. **verify** — el comando de verificación del proyecto (§ abajo) tiene que salir verde.
4. **archive** — el delta se funde en `specs/<dominio>/spec.md` y la carpeta se mueve a
   `changes/archive/<fecha>-<nombre>/`.

## Verificación de este proyecto

```bash
cd Packages/Platform && swift build && swift test
cd Packages/Features && swift build && swift test
Scripts/build-app.sh          # si existe; si no, xcodebuild sobre AppStarter.xcodeproj
```

Un cambio no se archiva sin eso en verde.

## Reglas de tamaño (lo que evita que esto se vaya de las manos)

- Un cambio = **4 ficheros como mucho** (proposal, tasks, delta, y design solo si lo pide).
- El delta describe **lo que cambia**, nunca repite la spec completa.
- Si un cambio necesita más de una carpeta en `changes/`, es dos cambios.
- La prosa que explica **por qué se hizo así** va al mensaje de commit. Aquí va lo que el
  sistema **hace**.
