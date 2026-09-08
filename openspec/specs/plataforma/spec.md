# plataforma Specification

## Purpose

Contrato de la capa de plataforma de AppStarter: qué garantizan los kits propios
(`AppFoundation`, `CoreNetworking`) a las features que los consumen, en las partes que
tienen comportamiento observable por el usuario.

Cubre solo lo verificado hasta hoy. Un requisito que no esté aquí no es que no exista: es
que nadie lo ha escrito todavía, y se añade cuando un cambio lo toque.

## Requirements

### Requirement: Cancelación del trabajo en vuelo al desmontar una pantalla

Una pantalla montada con `ScreenContainer` SHALL cancelar su trabajo asíncrono en vuelo
cuando la vista sea eliminada de la jerarquía de navegación, y SHALL NOT cancelarlo cuando
la vista quede únicamente cubierta por otra empujada encima.

El comportamiento se controla con `ScreenContainer(_:cancelsInFlightWorkOnRemoval:)`, cuyo
valor por defecto es `true` desde AppFoundation 1.3.0.

Cada pantalla que se aparte del default SHALL declarar por qué en el propio código.

#### Scenario: La pantalla se elimina de la jerarquía

- **WHEN** el usuario hace pop de una pantalla que tiene una carga en curso
- **THEN** el trabajo en vuelo se cancela
- **AND** no se entrega ningún resultado a una vista que ya no existe

#### Scenario: La pantalla queda cubierta por un push

- **WHEN** el usuario empuja otra pantalla encima de una que tiene una carga en curso
- **THEN** el trabajo en vuelo continúa
- **AND** al volver atrás la carga sigue siendo válida y no se repite

#### Scenario: El trabajo debe sobrevivir a su pantalla

- **WHEN** la pantalla es `UploadsView`, que sube una foto con barra de progreso
- **THEN** pasa `cancelsInFlightWorkOnRemoval: false`
- **AND** la subida continúa aunque el usuario navegue fuera

#### Scenario: Un login en vuelo pierde su pantalla

- **WHEN** `LoginView` tiene una petición de login en curso y su vista se elimina
- **THEN** la petición se cancela
- **AND** `LoginView` se queda con el default del kit, sin pasar el parámetro

Decidido por el owner el 2026-09-05: **el login se cancela**. Un login sin pantalla no
tiene a quién entregarle el resultado — ni la sesión que lo pidió, ni el formulario que
recogería el error. Y a diferencia de la subida de Uploads, repetirlo es barato: el usuario
vuelve a la pantalla y lo intenta otra vez, sin haber perdido nada por el camino.

### Requirement: El usuario no ve errores internos

Un error envuelto (`WrappedError`) SHALL presentar al usuario únicamente el mensaje de la
capa que lo envuelve. El error interno SHALL quedar disponible para el log y el
diagnóstico, y SHALL NOT aparecer en pantalla.

#### Scenario: Un fallo de red envuelto por una capa de dominio

- **WHEN** una operación falla y el error se envuelve antes de llegar a la vista
- **THEN** el texto en pantalla es el de la capa que envuelve
- **AND** el error original no forma parte de ese texto

### Requirement: Versión mínima de los kits

Los manifiestos del proyecto SHALL declarar AppFoundation `1.3.1` o superior y
CoreNetworking `1.2.2` o superior, en los tres sitios donde vive el suelo de versión:
`project.yml`, `Packages/Platform/Package.swift` y `Packages/Features/Package.swift`.

Por debajo de esas versiones el proyecto arrastra un fallo de seguridad ya corregido
(AppFoundation 1.2.6, el error interno visible para el usuario).

#### Scenario: Se resuelve el grafo de dependencias

- **WHEN** se ejecuta `swift package update` o `xcodebuild -resolvePackageDependencies`
- **THEN** los tres `Package.resolved` quedan en AppFoundation 1.3.1 o superior
- **AND** en CoreNetworking 1.2.2 o superior

### Requirement: Dónde vive un helper de test compartido

Un helper de test (mock, spy o utilidad) que necesiten **dos o más** targets `*FeatureTests`
SHALL vivir en `PlatformTestSupport`, y SHALL NOT duplicarse en cada target.

Un helper que solo use un target SHALL quedarse privado en él: mover a `PlatformTestSupport`
algo con un único consumidor convierte una decisión local en superficie pública para nadie.

#### Scenario: Un segundo target necesita un helper que ya existe

- **WHEN** un target de test necesita un helper que ya está escrito en otro target
- **THEN** el helper se mueve a `PlatformTestSupport` y ambos lo importan
- **AND** no queda ninguna copia privada

#### Scenario: Un helper con un solo consumidor

- **WHEN** solo un target de test usa un helper
- **THEN** se queda privado en ese target

### Requirement: Un texto de error que ven dos pantallas se escribe una vez

Un **par título+mensaje** que dos o más features muestran al usuario para el mismo error
SHALL estar definido una sola vez en `Domain`, y SHALL NOT escribirse como literal en cada
feature.

La unidad es el **par**, no el literal suelto: un mensaje puede repetirse acompañado de
títulos distintos —«No se pudo capturar» y «No se pudo guardar» comparten «Inténtalo de
nuevo.»— y esos son errores DISTINTOS que dan la casualidad de decir lo mismo. Atarlos a una
constante común los haría cambiar juntos sin motivo.

`Domain` SHALL seguir sin dependencias: los textos se guardan como `String`, nunca como el
tipo de presentación (`ScreenError`), que pertenece a la capa de UI.

Un **fixture de test** que reproduzca uno de esos pares SHALL leerlo también de `Domain`: si
lo escribe a mano, la imagen de referencia sigue verde mientras el texto real ya cambió.

#### Scenario: Dos features muestran el mismo error

- **WHEN** dos features presentan el mismo error de dominio con el mismo texto
- **THEN** el título y el mensaje salen de la misma constante en `Domain`
- **AND** cambiar el texto en un sitio lo cambia en las dos pantallas

#### Scenario: Dos errores distintos comparten mensaje

- **WHEN** dos features usan el mismo mensaje con títulos distintos
- **THEN** cada una lo conserva como literal propio
- **AND** no se unifican, porque no son el mismo error

#### Scenario: Un fixture de snapshot reproduce un par canónico

- **WHEN** un test de snapshot monta un estado de error con un par que vive en `Domain`
- **THEN** lo lee de la constante, no lo escribe a mano

### Requirement: Una cancelación que se lanza no se le presenta al usuario como error

Una feature cuya `Logic` **lanza** un error de dominio que representa cancelación SHALL
cumplir las cuatro cosas, o no lanzarlo:

1. su `mapError` SHALL traducir `APIError.Category.cancelled` a ese caso, no a `.unknown`;
2. ese caso SHALL tener `isRetryable == false` — ofrecer «Reintentar» sobre algo cancelado
   invita a deshacer la decisión que se acaba de tomar;
3. el caso SHALL estar registrado en el `CancellationRecognizing` de la app, para que
   `BaseViewModel` lo descarte antes de llegar a `setError`;
4. la feature SHALL devolver la fase a un estado del que se pueda salir, y SHALL hacerlo
   solo si su `Task` sigue viva.

La cuarta no es cosmética: `performLoad`/`performActivity` salen de una cancelación
reconocida por un `return` seco que no toca `phase`, así que la fase transitoria puesta
ANTES de arrancar se queda puesta y la pantalla se cuelga en `.loading` para siempre —sin
contenido, sin error, sin reintentar—, que es peor que mostrar el error. Y el reset tiene que
mirar `Task.isCancelled` porque `performLoad` cancela la carga anterior al arrancar la
nueva: sin esa condición, la superada le quita el indicador de progreso a la que la superó.

**El requisito se aplica a la cancelación que llega desde la red, que la pantalla nunca pidió
y que por tanto no debe presentar.** Y se aplica por lo que el error SIGNIFICA, no por cómo
se llame el caso: `UploadsError.captureCancelled` no se llama `cancelled` y entra igual en el
razonamiento.

Quedan fuera dos clases de cancelación, cada una por su motivo:

- **La que no se lanza.** Una feature cuya operación no es `throws` y guarda la cancelación
  como dato para pintarla —`DiagnosticsFeature` y su `DiagnosticsResult`— nunca llega a
  `BaseViewModel`, así que no le aplica.
- **La que no viene de la red y la pantalla presenta a sabiendas.**
  `UploadsError.captureCancelled` nace de `CameraCaptureError.cancelled` —el usuario cerrando
  la cámara sin disparar—, y ahí la cancelación ES el resultado de la pantalla
  («Cancelado / No se tomó ninguna foto.»). Cumple la cláusula 2 y NO debe cumplir las otras
  tres.

**Aquí no va un censo de las features que cumplen.** La versión anterior de este requisito
enumeraba «de las diez features… cuatro tienen un caso», y el número caducó con el primer
cambio que añadió una: al llegar `CartFeature` eran once y cinco. Un recuento sobre código
que el requisito no toca envejece solo y nadie vuelve a contarlo, así que lo que manda es el
criterio de arriba. Quien necesite el recuento de hoy, que lo mida:

```bash
grep -rln "enum [A-Za-z]*Error: DomainError" Packages/Features/Sources   # features con error propio
grep -rn  "case .*[Cc]ancel" Packages/Features/Sources                   # candidatas, a filtrar por SIGNIFICADO
```

#### Scenario: Una carga cancelada con la pantalla montada

- **WHEN** una carga de una feature que lanza cancelación falla con ella y la `Task` NO está cancelada
- **THEN** el view model no queda en estado de error
- **AND** tampoco queda en `.loading`: la pantalla se puede seguir usando

#### Scenario: Una carga superada por otra

- **WHEN** una segunda carga cancela a la primera y sigue en vuelo
- **THEN** la primera, al desenrollarse, no toca la fase
- **AND** la segunda conserva su indicador de progreso

#### Scenario: Un error de dominio normal

- **WHEN** una carga falla por un error que no es cancelación
- **THEN** el reconocedor no lo intercepta
- **AND** la pantalla muestra su error como siempre

#### Scenario: Una feature que expone la cancelación como dato

- **WHEN** una feature guarda el caso de cancelación en su resultado en vez de lanzarlo
- **THEN** este requisito no le aplica
- **AND** puede presentarlo como parte de su contenido

#### Scenario: Una feature nueva que lanza cancelación de red

- **WHEN** se añade una feature cuya `Logic` traduce `APIError.Category.cancelled` a un caso propio
- **THEN** ese caso queda registrado en el `CancellationRecognizing` de la app
- **AND** hay un test que se pone rojo si se quita del registro
