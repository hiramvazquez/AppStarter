# Diseño

## Context

Ver `proposal.md` — Why. **`CartError` y `GalleryError` tienen exactamente los mismos cinco casos**,
así que cualquier enumeración exhaustiva de ellos es idéntica salvo el nombre del tipo.

*Aquí decía que el detector «normaliza identificadores, así que la ve igual», y es **falso**.
Corregido el 2026-09-14 tras medirlo: `sin_ruido` (`busca-duplicados.py:69-72`) solo borra
comentarios y colapsa espacios — los identificadores entran crudos en el SHA-1. Y `cuerpos()`
huella lo que va **entre las llaves**, así que la firma queda fuera. Las dos mitades importan, y
juntas explican por qué mi medición original engañaba.*

## Goals / Non-Goals

**Goals.** Que el compilador vuelva a obligar a decidir la reintentabilidad de un caso nuevo. No
reintroducir duplicación.

**Non-Goals.** Cambiar el default de `TransportMappable`, ni tocar las features que conservan su
`switch` en producción.

## Decisions

**El `switch` exhaustivo va dentro del test de reintentabilidad que cada feature YA tiene**, sobre
`allCases`. Tres hechos lo respaldan, los tres medidos y no supuestos:

1. **Recupera la garantía.** Prototipo: añadir un caso al enum sin clasificarlo produce
   `error: switch must be exhaustive`. Es la misma barrera que daba el `switch` de producción.
2. **No crea duplicación.** Medido con el propio detector sobre los tres cuerpos tal como quedarían:
   `✅ sin lógica repetida en 3 ficheros Swift`. Funciona porque esos tests ya tienen asserts
   propios distintos —Cart cinco, Gallery tres, ProductDetail cuatro—, así que sus cuerpos difieren.
3. **Comprueba más que el `switch` original.** Al recorrer `allCases` comparando la clasificación
   explícita contra `isRetryable`, falla también si el default heredado deja de coincidir con lo que
   la feature decide. El `switch` de producción no podía detectar eso, porque él *era* la decisión.

### Alternativas descartadas, con su medición

**Un test nuevo y propio por feature.** Se descarta por ser superficie de más —un test extra por
feature para una aserción que ya tiene su sitio—, no por duplicación.

*Aquí decía que «crea un grupo de duplicados: `0d7f0aa593`, 5 líneas, 2 copias». **No reproduce**,
y el error era mío: en el experimento puse el tipo en la FIRMA (`func f(_ caso: CartError)`), que
el detector no huella, dejando cuerpos byte a byte idénticos. La alternativa real nunca tendría
esa forma: su bucle dice `CartError.allCases`, dentro del cuerpo, y entonces el detector NO
agrupa — comprobado con los dos experimentos aislando la variable. Descarté una alternativa contra
un número que no salía. Lo cazó el revisor.*

*Consecuencia buena, y conviene dejarla escrita porque responde a una duda real: la solución
elegida **no es frágil**. Si mañana alguien parte el bucle en un test propio por feature, el
duplicado sigue sin aparecer, porque los tipos difieren dentro del cuerpo.*

**Un helper compartido en `PlatformTestSupport` con el `switch` como closure.** Éste sí es
imposible, y por una razón que vale más que la de la duplicación: **un closure no puede dar
exhaustividad de compilador para el llamante**. El `switch` tiene que mencionar los casos del
enum concreto, así que es por-enum por definición. Además `CartFeatureTests` ni siquiera declara
`PlatformTestSupport` —lo importa sin declararlo—, así que apoyarse ahí sería construir sobre una
anomalía.

**Devolver el `switch` a producción**, vía un requisito del protocolo tipo
`var reintentabilidadPropia: Bool? { get }`. Daría la garantía, pero Cart y Gallery lo
implementarían idéntico: el mismo grupo de duplicados, ahora en producción y con más ceremonia.

**Conformar `CaseIterable` solo en los tests.** No se puede sin coste: la síntesis de `allCases`
exige declararlo con el enum; una conformidad retroactiva desde otro módulo obliga a escribir
`allCases` a mano, que es justo la lista que queremos que mantenga el compilador.

## Risks / Trade-offs

- **`CaseIterable` añade `allCases` a la API pública de los tres enums** → coste aceptado y con
  precedente en el repo (`DiagnosticsExperiment`). Nadie fuera de los tests lo consume.
- **La garantía vive en los tests, no en producción** → si alguien borra el test, desaparece sin
  que nada avise. Es la misma condición que tienen los demás contratos de esta casa que no puede
  comprobar un linter, y por eso la cláusula queda escrita en la spec.
- **Un caso con VALOR ASOCIADO rompe `CaseIterable`, y el arreglo barato mata la garantía** →
  añadir `case algo(String)` no compila, pero el error se muda a producción
  (`type 'X' does not conform to protocol 'CaseIterable'`) y la salida más rápida es borrar
  `CaseIterable` y el bucle: todo queda verde y la garantía muerta. Es un camino más probable que
  el borrado deliberado, porque lo empuja el compilador. Mitigación: la cláusula 7 de la spec y
  este párrafo; no hay detector.
- **Protege a las tres features que conforman el protocolo hoy** → las demás conservan su `switch`
  en producción y nunca perdieron la garantía. Pero la cláusula 7 obliga también a los
  conformantes FUTUROS y **nada lo hace cumplir**: una feature nueva que conforme
  `TransportMappable` sin declararse `CaseIterable` hereda en silencio y ningún test se pone rojo.
  Es el hueco honesto entre un SHALL y un mecanismo opt-in, y se declara en vez de fingir que la
  cláusula se aplica sola.

## Migration Plan

Mecánico: `CaseIterable` en tres declaraciones y un bucle en tres tests. Revertir es quitarlos.
