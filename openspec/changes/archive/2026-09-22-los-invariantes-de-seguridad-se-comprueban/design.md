# Diseño

## D1. Qué se comprueba a máquina y qué no

La línea no la marca la importancia del riesgo, sino si **se puede decidir mirando el código
sin entender qué hace la app**. Un token en plano se decide así; si esa pantalla debería ver
esos datos, no.

| invariante | se decide mirando | herramienta |
|---|---|---|
| no hay secretos en el árbol ni en la historia | el texto | gitleaks |
| nada imprime a consola en producción | el texto | SwiftLint (ya existía) |
| ningún log expone datos con `privacy: .public` | el texto | SwiftLint (ya existía) |
| ninguna URL de red es `http://` | el texto | SwiftLint, regla nueva |
| las credenciales no viven en `UserDefaults` | el texto | SwiftLint, regla nueva |
| no hay `try!`, `as!` ni `!` forzado | el texto | SwiftLint (ya existía) |
| las dependencias no tienen CVE conocidos | una base de datos externa | OSV-Scanner, en CI |
| quién puede ver qué | qué hace la app | el revisor |

## D2. Por qué SwiftLint y no semgrep

Medido el 2026-09-22 sobre un fichero con los tres casos delante:

| patrón semgrep | encuentra |
|---|---|
| `$D.set($V, forKey: $K)` | 0 |
| `UserDefaults.standard.set($V, forKey: $K)` | 0 |
| `URL(string: $S)` | 0 |
| `UserDefaults.standard` | 2 |

Con llamadas etiquetadas fuera de su alcance, semgrep no puede expresar estos invariantes en
Swift. SwiftLint, en cambio, ya está instalado, ya corre con `--strict` dentro de la
verificación —así que un `warning` suyo BLOQUEA— y su motor de reglas propias por regex ya
sostiene dos invariantes de este proyecto desde hace semanas. La regla es la del kit: restar
antes que añadir.

**Límite asumido:** una regla regex no entiende el código. `sesion_fuera_de_keychain` mira el
nombre del fichero y la aparición de `UserDefaults`, así que un almacén de credenciales
llamado de otra forma se le escapa. Se acepta porque el caso que importa —que alguien añada
otro almacén «como el que ya hay»— sí cae dentro, y porque la alternativa medida no funciona.

## D3. La excepción de la sesión: declarada, no silenciada

`UserDefaultsSessionStore` guarda el bearer token en `UserDefaults` por una decisión de
plantilla documentada en PRD-APP-01. La regla nueva lo detectaría.

**Decisión:** la excepción se declara en el `excluded` de la regla, nombrando el fichero, y el
motivo se escribe ahí mismo. No se baja la severidad ni se quita la regla.

Así, el día que alguien añada un segundo almacén, falla; y el día que se mueva a Keychain,
basta borrar una línea. Un `// swiftlint:disable` en el fichero haría lo mismo pero deja la
razón lejos de la lista de invariantes, que es donde alguien la va a buscar.

## D4. Las dependencias van al CI, no a cada commit

Un CVE nuevo no lo introduce tu commit: aparece cuando alguien publica un aviso. Comprobarlo
en cada verificación cobraría segundos y una llamada de red por commit para responder casi
siempre lo mismo. En CI, por PR y por empuje, basta.

**Consecuencia asumida:** entre dos corridas de CI puedes commitear sobre una dependencia con
un aviso recién publicado. Es el mismo trato que ya tiene el resto del CI en este proyecto.

**Lo que este job NO cubre, medido el 2026-09-22.** Los `Package.resolved` versionados
declaran solo los dos paquetes propios. El único tercero —`swift-snapshot-testing`, que usa el
target de snapshots— se declara en `project.yml`, y su fichero de versiones lo escribe
xcodegen dentro del `.xcodeproj`, que no está en git. Cubrirlo obligaría a resolver los
paquetes del proyecto de Xcode en el job, o sea runner de macOS y minutos, para vigilar UNA
dependencia de tests. No compensa hoy; el día que entre un tercero de producción, sí.
