# Unificar los textos de error comunes

## Why

`ProductsError` y `SearchError` son **el mismo enum escrito dos veces**: mismos tres casos
(`offline`, `server`, `unknown`), mismo `isRetryable`, y un `screenError` con los **mismos
seis literales de cara al usuario**, palabra por palabra.

`kit-duplicados` lo reporta (`ProductsLogic.swift:16` y `SearchLogic.swift:16`), pero el
riesgo no es la duplicación de código: es que son **textos que ve el usuario**. Quien
retoque «Comprueba tu red e inténtalo de nuevo.» en una pantalla no tiene forma de saber que
hay otra pantalla diciendo lo mismo, y las dos divergen sin que nadie se entere.

## What Changes

> **Reescrito tras el RED del reviewer y el DEVUELTO del juez de aceptación.** La primera
> versión migraba 2 features de 9 y declaraba en la spec una regla universal. El reviewer lo
> resumió mejor de lo que yo lo habría hecho: así entregado era **peor que no hacerlo** —
> antes había un mecanismo (literales por todas partes) y quien tocaba uno sabía que tocaba
> uno; después había dos, y quien editara la constante creería razonablemente haber cambiado
> el texto de toda la app. Una fuente de verdad que no manda sobre el 78% de sus consumidores
> es una trampa. Se completa la migración.

- Nace `Packages/Platform/Sources/Domain/ErrorCopy.swift` con los pares título/mensaje
  compartidos como constantes `String`, `nonisolated`.
- **Las nueve features** que muestran esos textos los leen de ahí: Products, Search,
  ProductDetail, Profile, Uploads, Gallery, Login, Favorites y Diagnostics.
- **Añadido tras la ronda 2** (AMBER del reviewer, ACUERDO-ROTO del juez): el par
  «No encontrado» + «Este producto ya no está disponible.» era el ÚNICO par que seguía
  duplicado —`ProductDetailLogic:42` y `GalleryLogic:40`— y falsificaba la spec el día del
  archivado. Sube a `ErrorCopy.NotFound`. Y la spec pasa a hablar de **pares**, no de
  literales sueltos, que es la unidad correcta: un mensaje repetido bajo títulos distintos
  son errores distintos.
- **Un texto cambia, y es el motivo de todo esto**: `DiagnosticsModels.swift` decía para
  `.server` el mensaje «Inténtalo de nuevo.» mientras las otras siete pantallas con ese caso
  decían «Inténtalo de nuevo más tarde.» para el MISMO error. Era la deriva que este cambio existe
  para impedir, **ya ocurrida**. Se alinea con el canónico, con la razón escrita en el código.
- `Domain` **no gana ninguna dependencia**: son `String` planos, no `ScreenError` (que es de
  `AppFoundation`). Ese es el motivo de que el sitio sea `Domain` y no `Networking`.

## Fuera de alcance

- Los enums en sí. Siguen siendo tipos distintos por feature: fundirlos exigiría que una
  `*Feature` importara otra, y R13 lo prohíbe.
- Dos `"Inténtalo de nuevo."` que quedan en `UploadsLogic:41` y `SettingsLogic:45`. Van con
  títulos propios («No se pudo capturar», «No se pudo guardar»): son otros errores que
  comparten mensaje por casualidad, no el canónico. Unificarlos por parecido los ataría a un
  texto que no es el suyo.
- `mapError`, `ProductRow` y los demás grupos del informe de duplicados.
- Localización real (String Catalog). Hoy los literales están en español en el código; este
  cambio los mueve, no cambia esa decisión.

## Criterios de aceptación

- [ ] `Packages/Platform/Sources/Domain/ErrorCopy.swift` define los cuatro pares
      título/mensaje (`Offline`, `Server`, `Unknown` y `NotFound`), y `Domain` sigue sin declarar dependencias en `Package.swift`.
- [ ] **Ningún par título+mensaje aparece dos veces** en `Packages/Features/Sources`.
      Comprobable con un comando, y esa es la prueba de que la spec es verdad el día que se
      archiva:
      `grep -rhoE 'ScreenError\(\s*title: "[^"]*",\s*message: "[^"]*"' Packages/Features/Sources | sort | uniq -c | sort -rn`
      → ninguna línea con cuenta ≥ 2.
- [ ] El texto que ve el usuario no cambia **salvo en un sitio declarado**:
      `DiagnosticsModels` `.server` pasa de «Inténtalo de nuevo.» a «Inténtalo de nuevo más
      tarde.», que es el canónico que ya usaban las otras siete pantallas con ese caso.
- [ ] Cambiar `ErrorCopy.Offline.message` cambia el texto en **las siete** pantallas que
      tienen caso `.offline` — Favorites y Diagnostics no lo tienen. Ninguna se queda con
      una copia propia.
- [ ] `/kit-verifica` en verde.

> **Criterio retirado, y por qué.** La primera versión pedía que «el informe de duplicados
> deje de listar `screenError`». Es **inalcanzable por construcción** y lo cazaron los dos
> jueces: `busca-duplicados.py` hashea la ESTRUCTURA del cuerpo normalizado, no sus
> literales, así que dos `switch` de tres casos siguen siendo gemelos aunque digan
> `ErrorCopy.Offline.title` en vez de `"Sin conexión"`. Solo lo cumpliría fundir los enums,
> que R13 prohíbe. Era una predicción sobre cómo funciona una herramienta, escrita sin
> comprobarla.
