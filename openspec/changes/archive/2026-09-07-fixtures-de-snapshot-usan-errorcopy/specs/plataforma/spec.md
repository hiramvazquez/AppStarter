## MODIFIED Requirements

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
