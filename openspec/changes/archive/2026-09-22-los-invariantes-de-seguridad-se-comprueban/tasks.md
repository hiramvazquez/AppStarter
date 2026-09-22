## 1. Secretos

- [x] 1.1 `.gitleaks.toml` en la raíz: extiende la config por defecto y excluye `.build/`,
      `DerivedData/` y `.swiftpm/`. Verificación: `gitleaks dir --config .gitleaks.toml .`
      no da hallazgos y tarda menos de un segundo (medido hoy: 136 ms; sin excluir, 11
      falsos positivos y 65 s).
      **Hecho:** `.gitleaks.toml` extiende la config por defecto y excluye las tres rutas. Medido: 0 hallazgos en 147 ms sobre 1,77 MB; sin la exclusión eran 11 falsos positivos y 65 s sobre 1,08 GB.
- [x] 1.2 Paso `secretos` en `kit.conf`, con esa config y `--redact` para que un hallazgo no
      se imprima entero en el informe. Verificación: el paso sale verde en el árbol actual.
      **Hecho:** paso `secretos`, el primero del informe. Verde en el árbol actual.
- [x] 1.3 Probarlo con un token falso: el paso se pone rojo, no se firma, y el commit queda
      bloqueado. Verificación: los tres resultados, anotados, y el árbol devuelto a su sitio.
      **Hecho:** con un token de GitHub falso en `App/PruebaSecreto.swift`, gitleaks sale con 1, el paso se pone `❌ secretos`, la verificación termina «sin firma útil» y el `git commit` queda bloqueado por la puerta («no hay verificación firmada»). El último commit del repo siguió siendo el anterior. Fichero borrado después.

## 2. Reglas de código

- [x] 2.1 `no_http_url` en `.swiftlint.yml`, junto a las dos reglas propias que ya hay.
      Verificación: un fichero con `"http://ejemplo.com"` hace que `swiftlint --strict` salga
      con código distinto de 0; sin él, 0.
      **Hecho:** con `URL(string: "http://ejemplo.com")` en `App/`, `swiftlint --strict` sale con 2 y nombra la regla; sin él, 0.
- [x] 2.2 `sesion_fuera_de_keychain`: `UserDefaults` en ficheros cuyo nombre nombre sesión,
      token o credencial, con la excepción de `Session.swift` declarada ahí mismo y con su
      motivo (PRD-APP-01). Verificación: el lint pasa en el árbol actual.
      **Hecho:** regla `sesion_fuera_de_keychain`, acotada por nombre de fichero con `included`, y la excepción de `Domain/Session.swift` declarada ahí mismo con su motivo (PRD-APP-01). El árbol actual pasa.
- [x] 2.3 Probar que un SEGUNDO almacén sí falla: un fichero de mentira
      `TokenStore.swift` con `UserDefaults` pone el lint en rojo. Verificación: el código de
      salida, anotado, y el fichero borrado después.
      **Hecho:** un `TokenStore.swift` de mentira con `UserDefaults` pone el lint en 2 y nombra la regla. Borrado después; el árbol vuelve a 0.

## 3. El acuerdo, donde el agente lo lee

- [x] 3.1 Sección en `AGENTS.md` con los seis invariantes y, en cada uno, con qué se
      comprueba. Verificación: la sección nombra los seis y no repite lo que ya dice la spec.
      **Hecho:** sección «Seguridad: lo que se da por hecho» en `AGENTS.md`, con los seis invariantes y qué comprueba cada uno, más las dos cosas que hay que saber antes de escribir: que un secreto commiteado hay que rotarlo, y cuál es la única excepción declarada.
- [x] 3.2 Que no se duplique: `AGENTS.md` dice la norma y apunta a la spec para el detalle.
      Verificación: la lista completa con sus escenarios aparece una vez.
      **Hecho:** `AGENTS.md` da la tabla y remite a la spec `seguridad` para el detalle; los escenarios viven solo en la spec.

## 4. Dependencias, en el CI

- [x] 4.1 Job `dependencias` en `.github/workflows/ci.yml` con OSV-Scanner sobre los
      `Package.resolved` de los dos paquetes. Verificación: el job aparece en la corrida y su
      resultado, anotado.
      **Hecho:** job `dependencias` en ubuntu, con OSV-Scanner sobre los dos `Package.resolved`. El YAML parsea y los seis jobs siguen ahí.
- [x] 4.2 Que falle de verdad cuando toca: comprobar contra qué base consulta y qué hace con
      un aviso. Verificación: lo que devuelva sobre las dependencias actuales, anotado —si
      hoy no hay avisos, decirlo, que es un resultado y no una ausencia de prueba.
      **Hecho, y cambió el alcance:** consultando `api.osv.dev` (ecosistema SwiftURL) con las dependencias de hoy —AppFoundation 1.4.2 y CoreNetworking 1.3.1, que son las ÚNICAS de los ficheros versionados— salen **cero avisos**. Es un resultado, no una ausencia de prueba. Y destapó el límite: el único tercero, `swift-snapshot-testing`, se declara en `project.yml` y su fichero de versiones no está en git, así que este job no lo cubre. Escrito en el propio job, en el diseño y en la propuesta.

## 5. Cierre

- [x] 5.1 `openspec validate los-invariantes-de-seguridad-se-comprueban --strict` en verde.
      **Hecho:** `Change 'los-invariantes-de-seguridad-se-comprueban' is valid`, y vuelto a
      comprobar tras cada corrección del acuerdo.
- [x] 5.2 `/kit-revisa` sobre el diff. Presupuesto: una ronda. Atención especial a los falsos
      positivos y falsos negativos de las dos reglas nuevas: una regla que bloquea lo que no
      debe se acaba desactivando, y eso es peor que no tenerla.
      **Ronda 1 (2026-09-22): AMBER**, con siete hallazgos, todos reproducidos. Comprobó antes
      lo que sí funciona: el paso falla cerrado sin config y sin gitleaks instalado, la
      excepción de `Session.swift` vale también con la invocación del CI, y el job del CI
      detecta de verdad —con un `Package.resolved` de mentira con `swift-nio 2.41.0` devuelve
      4 avisos y sale con 1—.
      Lo arreglado, por causa:
      - **Las dos reglas casaban dentro de comentarios**, y con `--strict` eso bloquea. El caso
        que lo demuestra: el día que la sesión pase a Keychain, el comentario que explique a
        qué sustituye pondría la verificación en rojo *por documentar*. Añadido `match_kinds`
        a las dos: `string` en la de URLs, `identifier`/`typeidentifier` en la de credenciales.
      - **El `excluded` silenciaba de más**: sin barras, `Tests`, `Mocks` y `TestSupport`
        valían como subcadena de la ruta ABSOLUTA, así que un clon en `~/Tests-varios/` apagaba
        la regla en todo el repo sin decir nada; y `included` sin anclar hacía que un clon bajo
        un directorio llamado `Token` casara todos los ficheros. Anclados los dos.
      - **`// gitleaks:allow` dejaba pasar un token**, que es justo la desactivación suelta que
        la spec prohíbe. Cerrado con `--ignore-gitleaks-allow`.
      - **`"HTTP://"` en mayúsculas no casaba** (`(?i)`), y `TestSupport` faltaba en la
        exclusión de esa regla, al revés que en su hermana.
      - **El job descargaba `latest` sin verificar**, en un cambio que va de cadena de
        suministro. Ahora fija v2.6.0 y comprueba el sha256 de la release. Y el workflow
        declara `permissions: contents: read`.
      - **Tres promesas del acuerdo eran más anchas que la comprobación**, y se corrigieron por
        escrito: la detección por nombre de fichero, que la firma no cubre `openspec/` —un
        secreto escrito ahí tras verificar no invalida la firma, lo caza la siguiente— y que
        nadie comprueba `Info.plist`.
      Comprobado después con cuatro casos: comentario con `UserDefaults` → pasa; código con
      `UserDefaults` → bloquea; `http://` en comentario → pasa; `HTTP://` en literal → bloquea.
      Va segunda vuelta: los arreglos cambian lo que hace el código.
      **Ronda 2 (2026-09-22): AMBER.** Confirmó con mediciones que los siete quedaron cerrados
      —incluidas las interpolaciones, los strings raw y las ramas `#if` inactivas, y que el sha
      fijado coincide con el `SHA256SUMS` publicado de v2.6.0—, y encontró dos que había
      metido YO al anclar las exclusiones:
      - **Los tres targets de test de la app quedaban fuera de la exclusión.** Anclé a un
        directorio llamado exactamente `Tests`, `Mocks` o `TestSupport`, y aquí se llaman
        `AppTests`, `AppUITests`, `AppSnapshotTests` y `PlatformTestSupport`. El stub offline
        de `AppUITests` —justo donde el mensaje de la regla manda ponerlo— bloqueaba.
      - **La rama `TestSupport` no casaba nada**, y los dos comentarios afirmaban que sí. Que
        no saltara era mérito de `match_kinds`, no de la exclusión.
      Arreglado mirando los nombres REALES de los directorios del repo:
      `[^/]*(Tests|Mocks|TestSupport)/` como componente. Comprobado con cinco casos —URL en
      `AppUITests`, `UserDefaults` en `AppTests`, URL en `PlatformTestSupport`, URL en `App/`
      y un segundo almacén en `Domain`— y por los tres caminos de invocación, incluida la
      orden del CI en los dos paquetes.
      Sus otros dos apuntes eran de prosa y están escritos: un `http://` dentro de un string
      multilínea se escapa, y un `.gitleaksignore` en la raíz puede tapar un hallazgo.
      **Decisión del owner: se cierra en dos rondas.** Los arreglos de la segunda son un patrón
      y tres frases, medidos con cinco casos.
- [x] 5.3 `/kit-verifica` en verde, con el paso nuevo dentro. Verificación: la firma y cuánto
      ha subido el tiempo total.
      **Hecho (2026-09-22):** verde, con `✅ secretos` el primero del informe. El paso tarda
      147 ms y la verificación entera sigue en unos 54 s: el coste no se nota.
