# Tareas

Dos features, y en cada una las cuatro cláusulas del requisito «Una cancelación que se lanza no
se le presenta al usuario como error». El patrón ya existe en `CartFeature`: se sigue, no se
inventa.

- [x] 1. `GalleryError`: caso `cancelled`, `isRetryable == false`, `screenError` propio.
- [x] 2. `GalleryLogic.mapError`: `.cancelled` deja de caer en `default: .unknown`.
- [x] 3. `GalleryViewModel`: captura la cancelación, devuelve la fase solo si su `Task` sigue
      viva, y la relanza.
- [x] 4. `ProductDetailError`: caso `cancelled`, `isRetryable == false`, `screenError` propio.
- [x] 5. `ProductDetailLogic.mapError`: lo mismo que la 2.
- [x] 6. `ProductDetailViewModel`: lo mismo que la 3.
- [x] 7. `App/AppCancellationRecognizer`: registra los dos casos nuevos; su lista pasa de dos
      tipos a cuatro.
- [x] 8. Tests por feature: la cancelación del transporte mapea a `.cancelled`, y la pantalla no
      queda en error ni colgada en `.loading`.
- [x] 9. `AppTests/CancellationRecognizerTests`: los dos tipos nuevos, más dos aserciones de que
      un error normal de cada feature NO se confunde con cancelación.
- [x] 10. `/kit-verifica` en verde. El detector pasa de 3 a 4 grupos: al cumplir las tres
      features la misma norma, sus `mapError` convergen y el `isRetryable` de Gallery queda
      igual que el de Cart. Medido y declarado en el proposal, no resuelto aquí — `CartError` y
      `GalleryError` son ya el mismo enum, y unificarlos es otro cambio.
- [x] 11. `/kit-revisa` y `/kit-acepta`, según el presupuesto declarado.
- [x] 12. De la revisión, los arreglos que la enmienda declara: el test de «carga superada» en
      las dos features nuevas —su `if !Task.isCancelled` no lo cubría nada—, `RecognizerDePrueba`
      a `PlatformTestSupport` (cinco copias fuera) y el par «Cancelado» a `ErrorCopy` (cuatro
      copias fuera). Los dos últimos son `SHALL` vivos que este cambio degradaba.
- [x] 13. Y un cuarto, que se destapó al escribir el test de la 12: ese test copió la `Puerta` de
      Cart en las dos features, dejándola en tres. Es el MISMO `SHALL` que la 12 —«dónde vive un
      helper de test compartido»—, así que va al mismo sitio: `PlatformTestSupport`. Medido
      contra HEAD: el detector pasa de 6 grupos a 4, que son los 3 del baseline con el `mapError`
      de Gallery+ProductDetail convertido en el de las tres features, más el `isRetryable`.

- Ronda 1 del juez: ACEPTADO · comportamiento: no. Devolvió tres errores de hecho en el texto,
  corregidos: el recuento del par «Cancelado» (cuatro, no tres), «son ya el mismo enum» (su
  `screenError` difiere) y el condicional de las features restantes (son tres, medidas).
- Ronda 1 del revisor: AMBER · cuatro hallazgos, tres de ellos arreglados en código.
