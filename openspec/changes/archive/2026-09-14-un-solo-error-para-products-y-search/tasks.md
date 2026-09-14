# Tareas

El alcance, por sitios, está en la enmienda del `proposal.md`; el recuento exacto lo da
`git status --porcelain -uall` cuando haga falta. Las tres primeras tareas se cerraron antes de
que el alcance se moviera; de la 4 a la 7 las añade esa enmienda; de la 8 en adelante salen de
la ronda 1 de revisión.

- [x] 1. `CatalogError` en `Networking`: los cuatro casos, `isRetryable`, `screenError` y el
      mapeo desde `APIError`. Se mueve lo que estaba en `ProductsLogic`, sin cambiarlo.
- [x] 2. `ProductsLogic` usa `CatalogError` y deja de declarar `ProductsError`.
- [x] 3. `SearchLogic` usa `CatalogError` y deja de declarar `SearchError`.
- [x] 4. `ProductsViewModel` y `SearchViewModel`: sus `catch` y sus `throw` de `.cancelled` pasan
      a `CatalogError`.
- [x] 5. `App/AppCancellationRecognizer`: su lista de tipos pasa de tres a dos —`CatalogError` y
      `CartError`—, sin cambiar a qué responde.
- [x] 6. Tests de las dos features: esperan `CatalogError`, sin perder lo que fijan hoy.
- [x] 7. `AppTests/CancellationRecognizerTests`: las aserciones sobre los tres tipos pasan a los
      dos que quedan.
- [x] 8. El test de `isRetryable` vive UNA vez, en `NetworkingTests/CatalogErrorTests`: al
      unificar el tipo, los dos `cancelacionNoEsReintentable()` de Products y Search quedaron
      idénticos y el detector los reportó como grupo nuevo.
- [x] 9. Los comentarios dicen dónde vive el tipo de verdad: los dos `*Logic` decían «en
      `Domain`», `SearchLogic` seguía citando `SearchError`, y `ErrorCopy` decía que
      `CatalogError` «vive al lado». Los cuatro corregidos.
- [x] 10. `AppCancellationRecognizer` deja de importar `Domain`, `ProductsFeature` y
      `SearchFeature`, que ya no usa; los dos ViewModels ordenan sus imports.
- [x] 11. `kit.conf` sale de este cambio: el `FUENTES` ampliado es otra decisión y va en su
      propio commit.
- [x] 12. El delta corrige la receta de censo de `plataforma`, que ya no ve a Products ni Search.
      Comprobado: la receta vieja devuelve 9 ficheros sin ver el error compartido; la corregida,
      10 incluyéndolo. El `MODIFIED` reproduce el requisito entero —incluidos los tres
      escenarios que omití en el primer intento, y que `openspec validate` rechazó por
      borrarlos: un MODIFIED reemplaza el bloque completo.
- [x] 13. Comprobar que `/kit-duplicados` sigue en 3 grupos, sin ninguno nuevo. Medido con el
      `FUENTES` original, que es el denominador correcto.
- [x] 14. `/kit-verifica` en verde: los cinco pasos, incluidos `xcodebuild`, `AppTests` y
      `AppSnapshotTests`.
- [x] 15. Ronda 2 del juez, que la regla de archivado exige tras un ACUERDO-ROTO. Resultado:
      tope alcanzado, sin veredicto, y los tres errores de hecho que dejó corregidos quitando el
      censo del acuerdo.

- Ronda 1 del juez: ACUERDO-ROTO · comportamiento: no (solo prosa y comentarios)
- Ronda 1 del revisor: AMBER
- Ronda 2 del juez: TOPE ALCANZADO · comportamiento: no. Dos rondas seguidas sin mover el
  código, así que no dio veredicto y eligió la salida «el código y el acuerdo están bien; lo que
  queda son errores de hecho en el texto». Los tres eran el mismo recuento de ficheros, mal
  contado por tercera vez — y uno lo había escrito el arreglo de la ronda anterior. Se cierra
  quitando el censo del acuerdo, no contando otra vez. Decide el owner: archivar.
