# Tareas

- [x] 1. `cancelled` en los dos enums, con `mapError` e `isRetryable == false`
- [x] 2. `App/AppCancellationRecognizer.swift` + registro en el composition root
- [x] 3. Una cancelación no deja la fase colgada en ninguno de los cuatro sitios
- [x] 4. El reset solo corre si la `Task` sigue viva — **los cuatro** con test que muere
- [x] 5. Tests que fijan la FASE, no solo `hasError`, cada uno verificado por mutación
- [x] 6. La spec escrita como condicional universal («la que lanza cancelación de red»),
      con las exclusiones de Diagnostics y Uploads nombradas y justificadas una a una
- [x] 7. `/kit-verifica` en verde
