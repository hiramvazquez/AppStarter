## 1. El esquema fija el locale

- [x] 1.1 `project.yml`: en `schemes.AppStarter.test`, añadir `language: en` y `region: US`,
      con un comentario al lado que diga por qué —el formateo con el locale del proceso, y
      que la norma vive en `plataforma`—, en el estilo del de `UI_TEST_OFFLINE`.
      Verificación: `git diff project.yml` toca solo ese bloque.
- [x] 1.2 Regenerar el proyecto con `Scripts/bootstrap.sh`. Sin esto `/kit-verifica` prueba
      el esquema viejo: el `.xcodeproj` está en `.gitignore` y `kit.conf` no lo regenera.
      Verificación:
      `grep -E 'language = "en"|region = "US"' AppStarter.xcodeproj/xcshareddata/xcschemes/AppStarter.xcscheme`
      devuelve dos líneas.
- [x] 1.3 **La premisa, sobre el proyecto de verdad y antes de regrabar nada.** Con el esquema
      fijado y las referencias viejas, correr solo la suite del carrito con el flujo de
      `kit.conf`:
      `xcodebuild build-for-testing -project AppStarter.xcodeproj -scheme AppStarter -destination "platform=iOS Simulator,name=iPhone 17" -skipPackagePluginValidation CODE_SIGNING_ALLOWED=NO -quiet`
      y después
      `xcodebuild test-without-building -project AppStarter.xcodeproj -scheme AppStarter -destination "platform=iOS Simulator,name=iPhone 17" -only-testing:AppSnapshotTests/CartSnapshotTests CODE_SIGNING_ALLOWED=NO`.
      Verificación: `testContentKit` y `testContentSinDescuentoKit` **fallan** en local —hoy
      pasan— y los otros cuatro tests de la suite pasan. Se anota aquí el resultado.
      Si los dos siguen pasando, el ajuste no está llegando al proceso de test: se para y se
      anota, no se regraba nada.
      **Resultado (2026-09-18, Xcode 27.0 27A266a, xcodegen 2.46.0):** se cumple.
      `build-for-testing` exit 0; `test-without-building` exit 65, `Executed 6 tests, with 2
      failures (0 unexpected)`, `** TEST EXECUTE FAILED **`. Fallan `testContentKit`
      (`CartSnapshotTests.swift:151`) y `testContentSinDescuentoKit` (`:158`), los dos con
      «Snapshot "kit" does not match reference.»; pasan `testEmptyBrand`, `testEmptyKit`,
      `testErrorBrand` y `testErrorKit`. La imagen que pintó el proceso para `testContentKit`
      —la deja SnapshotTesting en el `tmp` del simulador— lleva `$1,620.00`, `$1,481.20` y
      `$3,280.19`, sin `US`: el ajuste llega al proceso de `AppSnapshotTests` y lo que
      difiere es el símbolo.
      De paso queda medido lo que `design.md` §3 dejó abierto: de los dos simuladores
      «iPhone 17», `xcodebuild` eligió `5D878DA7-F83F-4FD9-A56D-DB196FEDB3B2`, el de
      **iOS 27.0**.

## 2. Las dos referencias

- [x] 2.1 Borrar `AppSnapshotTests/__Snapshots__/CartSnapshotTests/testContentKit.kit.png` y
      `testContentSinDescuentoKit.kit.png`, y repetir el `test-without-building` de la 1.3.
      SnapshotTesting graba las que faltan y falla esa pasada, que es lo esperado.
      Verificación: los dos PNG vuelven a existir y `git status` los da como modificados, no
      como borrados.
- [x] 2.2 Abrir las dos referencias nuevas y compararlas con las anteriores
      (`git show HEAD:<ruta> > /tmp/antes.png`). Verificación: los importes salen como
      `$1,620.00`, sin `US` delante, y nada más ha cambiado —mismas líneas, mismos textos,
      mismo tachado en la de descuento y ninguno en la de sin descuento—. Se anota lo visto.
      **Decisión del owner (2026-09-18):** el reflujo descrito abajo se acepta como
      consecuencia del importe más estrecho. La tarea se marca con la frase de verificación
      intacta: «nada más ha cambiado» no se cumple al pie de la letra, y queda dicho aquí en
      vez de reescribir la frase para que encaje.
      **Lo visto (2026-09-18).** Se dejó sin marcar hasta esa decisión, porque la
      verificación no se cumple al pie de la letra.
      Se cumple: en las dos, todos los importes salen sin `US` —`3 × $540.00`, `$1,620.00`,
      `$1,481.20`, `1 × $1,999.99`, `$1,999.99`, `$1,798.99`, `$3,619.99`, `−$339.80`,
      `$3,280.19`—; las mismas dos líneas de carrito y los mismos textos («4 artículos»,
      Subtotal, Descuento, Total); tachados `$1,620.00` y `$1,999.99` en la de descuento y
      ninguno en la de sin descuento.
      **No se cumple «nada más ha cambiado»**: el título «Apple MacBook Pro 14 Inch Space
      Grey» pasa de tres renglones («Apple MacBook / Pro 14 Inch Space / Grey») a dos («Apple
      MacBook Pro / 14 Inch Space Grey»). La tarjeta queda un renglón más baja y todo lo que
      hay debajo sube. Medido con un diff de píxeles (1206×2622): difiere el 5,00 % en
      `testContentKit` y el 4,26 % en `testContentSinDescuentoKit` —`precision: 0.98` tolera
      un 2 %—, y de `y=760` hacia abajo la columna izquierda de la imagen nueva es la vieja
      subida exactamente 66 px (22 pt a @3x, un renglón de título), con 8 y 2 px de resto.
      Es consecuencia del propio cambio, no un cambio aparte: sin `US` la columna de importes
      es ~68 px (~23 pt) más estrecha, la del título gana ese ancho, y «Apple MacBook Pro»
      (~448 px, ~149 pt), que antes no cabía, ahora cabe. Esas dos medidas están leídas a ojo
      sobre la imagen, no con el diff. La 1.3 lo respalda: la referencia nueva de
      `testContentKit` es byte a byte (sha256 `ee93f16f…`) la imagen con la que falló allí,
      pintada por el mismo simulador con solo el esquema cambiado. No hay forma de tener
      `$1,999.99` y tres renglones sin tocar `CartView`, que está fuera de alcance.
      Resto sin explicar, anotado como **hipótesis, no medido**: en texto que no cambia ni se
      mueve —la banda del título «Charger SXY 21», `y 120…200`— hay 182 px con alguna
      diferencia (delta máximo 69/255 por canal; 10 px por encima de 8/255); la cabecera
      vacía, `y 0…100`, es idéntica bit a bit. Es antialiasing, un 0,006 % de la imagen, muy
      por debajo de la tolerancia. Puede ser que las referencias del 2026-09-15 se grabaran
      con otro runtime —hay un «iPhone 17» de iOS 26.5— o que el idioma del proceso toque el
      rasterizado; no se ha separado una cosa de otra.
      **Añadido tras `/kit-revisa`**, que midió dos cosas por su cuenta: (a) en la banda del
      `$1,481.20` el texto va de `x=802…1106` antes a `x=869…1106` después —mismo borde
      derecho, **67 px** más estrecho—, que sustituye a mi lectura a ojo de arriba; (b) la
      banda del stepper de la fila 1, `y 307…360` —cápsula, glifos y bordes con
      antialiasing—, es idéntica bit a bit. Lo segundo pesa contra la hipótesis de «otro
      runtime» para el resto del título: un runtime distinto no respetaría la cápsula de la
      misma fila. El revisor lo da por la misma causa (el contenedor del título cambió de
      ancho); sigue sin estar reproducido, así que aquí se queda como lo más probable, no
      como medido.
- [x] 2.3 Repetir el `test-without-building` de la 1.3. Verificación: los seis tests de
      `CartSnapshotTests` pasan.
      **Resultado (2026-09-18):** exit 0, `Executed 6 tests, with 0 failures (0 unexpected)`,
      `** TEST EXECUTE SUCCEEDED **`.

## 3. Cierre

- [x] 3.1 `git status` y `git diff --stat`. Verificación: el cambio toca `project.yml`, las
      dos referencias PNG y `openspec/changes/los-snapshots-fijan-su-locale/`. Ningún
      `.swift` y ninguna otra referencia. Si `AppSnapshotTests` entero ha hecho caer alguna
      otra, no se regraba: se anota aquí y se decide por escrito.
      **Resultado (2026-09-18):** cuatro ficheros —`project.yml` (+12), los dos PNG
      (`156911 -> 147970` y `131947 -> 125753` bytes) y este `tasks.md`—. Ningún `.swift`,
      ninguna otra referencia; `el-ci-fija-el-xcode-con-el-que-prueba` y `.github/` sin tocar.
- [x] 3.2 Stagear, `/kit-verifica` en verde con el proyecto regenerado, y `/kit-revisa`.
      Verificación: la firma verde, con `App · build + AppTests + AppSnapshotTests` entre sus
      pasos, y el revisor sin hallazgos que bloqueen.
      **Resultado (2026-09-18):** firma `verificado: 2026-09-18T19:51:17Z`,
      `diff: 5e0efef9…`, `resultado: verde`, `toolchain: Swift 6.4 · Xcode 27.0`, los ocho
      pasos en ✅ con `App · build + AppTests + AppSnapshotTests` entre ellos (1 min 06 s).
      `AppSnapshotTests` entero pasa en `en_US`: ninguna otra referencia ha caído, que es lo
      que dejaba pendiente la 3.1. El informe del kit solo da ✅ por paso, sin la última
      línea de cada comando; la única cola citada en este fichero es la de la 2.3.
      `/kit-revisa`: **GREEN**, sin hallazgos que bloqueen, punto marcado. Comprobó que
      `language`/`region` salen como atributos de `<TestAction>` en el `.xcscheme` y en
      ningún otro sitio, y que `AppUITests` no asevera texto del sistema que dependa del
      idioma salvo `"Back"`/`"Close"`, que vienen del `Localizable.xcstrings` de AppFoundation
      (`es`: «Atrás»/«Cerrar» — reverificado aquí): fijar `en` los clava en lo que asertan.
      Una nota suya sin acción: el comentario de `project.yml` apunta a un requisito que no
      existe en `openspec/specs/plataforma/spec.md` hasta archivar; es lo que pedía la 1.1.
      **Ojo:** esa firma es del árbol anterior a esta anotación. Escribir aquí el resultado
      de la firma invalida la firma; se repite `/kit-verifica` justo antes del commit.
- [ ] 3.3 **La prueba de verdad**: la corrida del CI sobre el commit del cambio. Va después de
      `/kit-verifica` por necesidad —el CI solo corre sobre lo ya empujado—, no porque importe
      menos. `main` ya está en rojo por estos dos tests, así que empujar no rompe ningún
      verde.
      Verificación: el número de run, anotado aquí, con el job
      `App (xcodebuild test: unit + snapshot + UI, offline)` en `success`.
      **Si el job sigue rojo por estos dos tests**, no se toca nada más: se anota el run, se
      descarga su artefacto `TestResults.xcresult`, se compara la imagen que pintó el runner
      con la referencia y se escribe qué difiere. Con eso se decide por escrito si entra en
      este cambio o es de `el-ci-fija-el-xcode-con-el-que-prueba`.
      **Si falla otra cosa** —un `XCUITest`, un test de `AppTests`—, es un hallazgo de haber
      fijado el locale para los tres targets: se anota el test y el mensaje, y se decide.
