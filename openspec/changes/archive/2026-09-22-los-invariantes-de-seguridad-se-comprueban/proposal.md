# Los invariantes de seguridad se comprueban, no se suponen

## Why

Hoy la seguridad de este proyecto descansa en una sola pieza: el revisor. Su prompt le pide
«corrección, **seguridad**, o un requisito explícito del encargo», y es un modelo leyendo un
diff. Eso tiene tres límites que no se arreglan pidiéndole más:

1. **No es obligatorio de forma mecánica.** Es una regla escrita; la puerta de commit no
   comprueba que haya habido revisión.
2. **Solo ve la rodaja**, lo que cambió desde la última revisión marcada. Lo que entró en un
   commit que nadie revisó no vuelve a pasar por delante de nadie.
3. **Es un juicio, no una comprobación.** Un token en plano lo caza «casi siempre»; un
   escáner lo caza siempre.

Hay cosas que en una app seria **se dan por hechas**, y eso es justo lo que se puede
comprobar a máquina. Este cambio escribe cuáles son y les pone detrás una comprobación que
corre en cada verificación, de modo que si alguna se incumple **no hay firma y la puerta
bloquea el commit**.

**Estado medido el 2026-09-22, antes de escribir nada:**

- `gitleaks` sobre la historia: **128 commits, sin hallazgos**.
- `gitleaks` sobre el árbol: 11 hallazgos, **los 11 falsos positivos** dentro de
  `Packages/*/.build/plugins/*/cache/*.json` — hashes de caché que parecen claves. Con las
  rutas de build excluidas: 0 hallazgos en 136 ms.
- `try!`, `as!` y `!` forzado: ya los bloquea SwiftLint (`force_try`, `force_cast`,
  `force_unwrapping` en el opt-in), y **no hay ninguno** en producción.
- `print(` y `privacy: .public`: ya hay reglas propias, y con `--strict` son error. Medido:
  un fichero con ambos sale con código 2.
- URLs `http://` en código: **ninguna**. `NSAppTransportSecurity` en `App/Info.plist`: **no
  está**, así que ATS queda en su valor por defecto, que es el seguro.
- **El bearer token se guarda en `UserDefaults`**, no en Keychain
  (`Packages/Platform/Sources/Domain/Session.swift`, `UserDefaultsSessionStore`). Es una
  decisión deliberada y documentada de esta plantilla (PRD-APP-01) para poder clonar y correr
  sin aprovisionar Keychain, con la nota de que un fork de producción la sustituya.

O sea: casi todo ya se cumple, pero **nada lo comprueba**, y la única excepción real —la
sesión en `UserDefaults`— solo está escrita en un comentario del fichero que la implementa.

## What Changes

- **`.gitleaks.toml` en la raíz**: config que extiende la por defecto y excluye `.build/`,
  `DerivedData/` y `.swiftpm/`, que es lo que provoca los 11 falsos positivos.
- **`kit.conf`**: un paso nuevo, `secretos`, que corre `gitleaks dir` sobre el árbol con esa
  config. Medido: 136 ms.
- **`.swiftlint.yml`**: reglas propias nuevas, en el mismo sitio donde ya viven
  `no_print_in_production` y `os_log_public_interpolation`:
  - `no_http_url`: un literal `"http://…"` en código.
  - `sesion_fuera_de_keychain`: `UserDefaults` en un fichero cuyo nombre nombra sesión,
    token o credencial. La excepción de `Session.swift` se declara con la razón, no se
    silencia.
- **`AGENTS.md`**: una sección corta con los invariantes, para que el agente los lea ANTES de
  escribir, no después.
- **`.github/workflows/ci.yml`**: un job `dependencias` que pasa OSV-Scanner sobre los
  `Package.resolved` versionados. Va en CI y no en `kit.conf` porque lo que cambia no es el
  código: es el mundo, y no tiene sentido pagarlo en cada commit.

  *Medido al implementar, el 2026-09-22:* esos dos ficheros declaran **solo los dos paquetes
  propios** (AppFoundation 1.4.2, CoreNetworking 1.3.1), y OSV no tiene avisos de ninguno. El
  único tercero del proyecto es `swift-snapshot-testing`, declarado en `project.yml` para el
  target de tests, y su fichero de versiones vive en el `.xcodeproj` que genera xcodegen, que
  no está en git. **Queda fuera de este job**, y se dice aquí en vez de dejar creer que está
  cubierto. Hoy la superficie de terceros es esa: una dependencia, solo de tests.

## Fuera de alcance

- **semgrep.** Medido el 2026-09-22 y descartado con datos: su soporte de Swift no casa
  llamadas con etiquetas. `$D.set($V, forKey: $K)` no encuentra el
  `defaults.set(data, forKey: key)` que hay en `Session.swift`, ni `URL(string: $S)` encuentra
  una URL; solo casa expresiones simples como `UserDefaults.standard`. Con eso no se puede
  escribir ninguno de estos invariantes.
- **Mover la sesión a Keychain.** Es la decisión de plantilla de PRD-APP-01 y merece su propio
  cambio. Aquí solo se declara la excepción por escrito y se impide que aparezca una segunda.
- **Análisis dinámico, MobSF, pentesting.** Otra liga, y no por commit.
- **Autorización y lógica de negocio** —quién puede ver qué—: eso no es mecánico y se queda
  donde está, en el revisor.
- **Rotar un secreto filtrado.** Es proceso, no código: borrarlo del fichero no lo desfiltra.
- **El kit.** Nada de esto entra en `ios-agent-kit`: lo que significa «verificado» lo decide
  cada proyecto en su `kit.conf`, y obligar a todos a tener gitleaks sería crecer por hallazgo.

## Criterios de aceptación

- [ ] Existe `.gitleaks.toml` en la raíz, extiende la config por defecto y excluye `.build/`,
      `DerivedData/` y `.swiftpm/`.
- [ ] `kit.conf` tiene un paso que corre gitleaks con esa config y sale en rojo si hay
      hallazgos. Comprobado metiendo un token falso: el paso se pone rojo, no se firma, y la
      puerta bloquea el commit.
- [ ] `.swiftlint.yml` tiene `no_http_url`, y con `--strict` un literal `"http://"` en código
      de producción sale con código distinto de 0.
- [ ] `.swiftlint.yml` tiene `sesion_fuera_de_keychain`, y la ÚNICA excepción declarada es
      `UserDefaultsSessionStore`, con su motivo escrito junto a la excepción.
- [ ] Un segundo almacén de credenciales sobre `UserDefaults` hace fallar el lint. Comprobado
      añadiendo uno de mentira.
- [ ] `AGENTS.md` lista los invariantes en una sección propia, cada uno dice con qué se
      comprueba, y la frase sobre la puerta dice la verdad también para `openspec/`.
- [ ] Las dos reglas nuevas NO saltan dentro de comentarios ni documentación, y sí en código.
      Comprobado con los cuatro casos: comentario que menciona `UserDefaults`, código que lo
      usa, `http://` en comentario y `HTTP://` en literal.
- [ ] Un `// gitleaks:allow` junto a un token NO lo deja pasar.
- [ ] El CI tiene un job `dependencias` que falla si OSV-Scanner encuentra una vulnerabilidad
      conocida en los `Package.resolved` versionados, y el propio job dice qué cubre y qué no.
- [ ] `/kit-verifica` en verde, con el paso nuevo dentro, y la verificación no tarda más de
      cinco segundos extra.
