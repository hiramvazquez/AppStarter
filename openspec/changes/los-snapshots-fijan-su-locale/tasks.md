## 1. El esquema fija el locale

- [ ] 1.1 `project.yml`: en `schemes.AppStarter.test`, añadir `language: en` y `region: US`,
      con un comentario al lado que diga por qué —el formateo con el locale del proceso, y
      que la norma vive en `plataforma`—, en el estilo del de `UI_TEST_OFFLINE`.
      Verificación: `git diff project.yml` toca solo ese bloque.
- [ ] 1.2 Regenerar el proyecto con `Scripts/bootstrap.sh`. Sin esto `/kit-verifica` prueba
      el esquema viejo: el `.xcodeproj` está en `.gitignore` y `kit.conf` no lo regenera.
      Verificación:
      `grep -E 'language = "en"|region = "US"' AppStarter.xcodeproj/xcshareddata/xcschemes/AppStarter.xcscheme`
      devuelve dos líneas.
- [ ] 1.3 **La premisa, sobre el proyecto de verdad y antes de regrabar nada.** Con el esquema
      fijado y las referencias viejas, correr solo la suite del carrito con el flujo de
      `kit.conf`:
      `xcodebuild build-for-testing -project AppStarter.xcodeproj -scheme AppStarter -destination "platform=iOS Simulator,name=iPhone 17" -skipPackagePluginValidation CODE_SIGNING_ALLOWED=NO -quiet`
      y después
      `xcodebuild test-without-building -project AppStarter.xcodeproj -scheme AppStarter -destination "platform=iOS Simulator,name=iPhone 17" -only-testing:AppSnapshotTests/CartSnapshotTests CODE_SIGNING_ALLOWED=NO`.
      Verificación: `testContentKit` y `testContentSinDescuentoKit` **fallan** en local —hoy
      pasan— y los otros cuatro tests de la suite pasan. Se anota aquí el resultado.
      Si los dos siguen pasando, el ajuste no está llegando al proceso de test: se para y se
      anota, no se regraba nada.

## 2. Las dos referencias

- [ ] 2.1 Borrar `AppSnapshotTests/__Snapshots__/CartSnapshotTests/testContentKit.kit.png` y
      `testContentSinDescuentoKit.kit.png`, y repetir el `test-without-building` de la 1.3.
      SnapshotTesting graba las que faltan y falla esa pasada, que es lo esperado.
      Verificación: los dos PNG vuelven a existir y `git status` los da como modificados, no
      como borrados.
- [ ] 2.2 Abrir las dos referencias nuevas y compararlas con las anteriores
      (`git show HEAD:<ruta> > /tmp/antes.png`). Verificación: los importes salen como
      `$1,620.00`, sin `US` delante, y nada más ha cambiado —mismas líneas, mismos textos,
      mismo tachado en la de descuento y ninguno en la de sin descuento—. Se anota lo visto.
- [ ] 2.3 Repetir el `test-without-building` de la 1.3. Verificación: los seis tests de
      `CartSnapshotTests` pasan.

## 3. Cierre

- [ ] 3.1 `git status` y `git diff --stat`. Verificación: el cambio toca `project.yml`, las
      dos referencias PNG y `openspec/changes/los-snapshots-fijan-su-locale/`. Ningún
      `.swift` y ninguna otra referencia. Si `AppSnapshotTests` entero ha hecho caer alguna
      otra, no se regraba: se anota aquí y se decide por escrito.
- [ ] 3.2 Stagear, `/kit-verifica` en verde con el proyecto regenerado, y `/kit-revisa`.
      Verificación: la firma verde, con `App · build + AppTests + AppSnapshotTests` entre sus
      pasos, y el revisor sin hallazgos que bloqueen.
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
