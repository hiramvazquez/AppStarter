## Context

El motivo, las corridas de CI y la cadena causal están en `proposal.md`. Lo que condiciona el
cómo:

- `Packages/Features/Package.swift:9-11` compila el paquete con `defaultIsolation(MainActor)`,
  `InferIsolatedConformances` y `NonisolatedNonsendingByDefault`. Los tres juntos son los que
  producen el fallo: el primero aísla el tipo, el segundo infiere aislada su conformidad, y el
  tercero hace que un `async` sin anotar herede el aislamiento del llamante.
- El patrón que el repo ya usa para esto es `nonisolated` en el tipo:
  `public nonisolated struct AppSettings: Sendable, Equatable, Codable`
  (`Packages/Platform/Sources/Networking/AppSettings.swift:17`) y
  `public nonisolated struct StoredSession: Sendable, Equatable, Codable`
  (`Packages/Platform/Sources/Domain/Session.swift:6`). Viene de AppFoundation, que declara
  así los DTO de sus ejemplos y de sus tests.
- `UploadPayload` es `private` y solo lo usa `UploadsService.addProduct`. No hay conformantes
  ni tests que dependan de su aislamiento.

## Goals / Non-Goals

**Goals**

- Que el fichero compile con el toolchain del CI **y** con el de esta máquina, no en uno a
  costa del otro.
- Que la regla quede escrita donde ya vive la mitad que sí estaba.

**Non-Goals**

- Decidir qué toolchain soporta AppStarter. Es del owner y va en otro cambio.
- Revisar el resto de anotaciones de `d575e75`.

## Decisions

### D1. `nonisolated` en el tipo, no en la conformidad

`private nonisolated struct UploadPayload: Encodable, Sendable`.

*Por qué:* es el patrón que el repo ya tiene para sus DTO, y dice lo que el tipo es —dos
`String` que se serializan fuera del MainActor—, no solo lo que hace falta para que este error
concreto desaparezca.

*Alternativa descartada — `struct UploadPayload: nonisolated Encodable`* (conformidad
`nonisolated`, SE-0470): arregla exactamente esta línea y deja el tipo aislado al MainActor
para todo lo demás. Cualquier miembro que se le añada mañana vuelve a nacer aislado, y el
siguiente uso fuera del MainActor vuelve a fallar en 6.2.4 y no en 6.4 — es decir, el rojo
volvería a aparecer solo en el CI.

*Alternativa descartada — codificar dentro del MainActor* (`await MainActor.run { … }` o
anotar `addProduct`): mete un salto de aislamiento para serializar dos cadenas, y deshace lo
que `d575e75` hizo a propósito con `UploadsServicing`, que era dejar de clavar la subida al
main actor.

### D2. La regla entra en el requisito que ya existe, no en uno nuevo

El requisito «Un contrato que implementa un actor se declara nonisolated» ya explica que
`defaultIsolation(MainActor)` obliga a anotar. Le falta la otra mitad: los **tipos** cuya
conformidad se infiere aislada.

*Por qué:* es el mismo hecho con dos consecuencias, y separarlo en dos requisitos deja a quien
lee el primero creyendo que con los protocolos está cubierto — que es exactamente lo que pasó
en `d575e75`.

*El nombre del requisito se queda corto, y aun así no se cambia:* en todo el historial de
`openspec/changes/archive/` solo se han usado deltas `ADDED` y `MODIFIED`, así que renombrar
exigiría borrar el requisito y volver a añadirlo. En vez de eso, el cuerpo dice el alcance en su
primera línea: esto vale para protocolos y para tipos.

## Risks / Trade-offs

- **[El arreglo no se puede verificar en local]** → el toolchain que da el error no compila
  contra el SDK de esta máquina. Se declara como límite en los criterios y la prueba la da el
  CI. Es el mismo trato que `spm-pro` le da a su mínimo soportado.
- **[Detrás de este rojo puede haber otro]** → los jobs `Platform`, `Integration` y `App` se
  quedaron cancelados o saltados por el fail-fast, así que no hay dato de hoy sobre ellos. Se
  dice en «Fuera de alcance»: si alguno sale rojo al desbloquearse, es un hallazgo nuevo.
- **[Anotar por costumbre]** → `nonisolated` en un tipo que sí necesita el MainActor mueve el
  fallo al uso en vez de resolverlo, como ya advierte el requisito para los protocolos. Aquí no
  aplica: el DTO no toca estado de UI ni tiene miembros aislados.
