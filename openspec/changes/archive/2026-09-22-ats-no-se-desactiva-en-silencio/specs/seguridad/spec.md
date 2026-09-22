## MODIFIED Requirements

### Requirement: Los invariantes de seguridad se comprueban en cada verificación

El proyecto SHALL declarar por escrito qué se da por hecho en materia de seguridad, y cada uno
de esos invariantes SHALL tener detrás una comprobación que corra dentro de `/kit-verifica`.
Un invariante incumplido MUST poner en rojo la verificación, de modo que no haya firma y la
puerta de commit bloquee.

Los invariantes son:

1. No hay secretos —claves, tokens, credenciales— en el árbol de trabajo.
2. Nada imprime a la consola en código de producción.
3. Ningún log expone valores con `privacy: .public`.
4. Ninguna URL de red del código usa `http://`.
5. Las credenciales no se persisten en `UserDefaults`.
6. No hay `try!`, `as!` ni desempaquetado forzado en código de producción.
7. La app no desactiva App Transport Security: ni en el `Info.plist` ni en la fuente desde la
   que se genera.

Estas comprobaciones son de TEXTO, no de semántica, y el alcance de cada una MUST estar
escrito donde vive la comprobación. Hoy: el almacén de credenciales se detecta por el NOMBRE
del fichero —sesión, token, credencial, keychain—, así que uno llamado de otra forma se
escapa; las URLs se detectan en literales de una línea, así que una construida por concatenación o
escrita dentro de un string multilínea se escapa;
el escaneo de secretos no ve un fichero que no pueda leer; y el de ATS mira `project.yml` y
los plists del árbol, así que un `xcconfig` se le escapa. Que vigile la clave
`NSAppTransportSecurity` entera y no cada variante NO es un hueco: toda relajación real de ATS
pasa por esa clave. Se aceptan porque el caso que
importa —alguien añade otro «como el que ya hay»— sí cae dentro, y porque la alternativa
semántica, medida el 2026-09-22, no funciona en Swift.

La comprobación de cada invariante MUST poder decidirse mirando el código, sin entender qué
hace la app. Lo que exija entenderlo —quién puede ver qué datos, si una autorización está bien
puesta— NOT MUST ponerse aquí: es del revisor, y fingir que un regex lo cubre es peor que no
tenerlo.

#### Scenario: Alguien escribe una credencial en el código

- **WHEN** el árbol contiene una clave o token en claro y se verifica
- **THEN** la verificación sale en rojo, no se firma, y la puerta bloquea el commit

#### Scenario: Alguien añade una URL sin TLS

- **WHEN** aparece un literal `http://` en código de producción y se verifica
- **THEN** la verificación sale en rojo

#### Scenario: Un artefacto de build parece una credencial

- **WHEN** un fichero de `.build/`, `DerivedData/` o `.swiftpm/` contiene una cadena que un
  escáner de secretos confunde con una clave
- **THEN** la verificación NO se pone en rojo por ello

#### Scenario: Se escribe un secreto dentro de openspec/

- **WHEN** se escribe un secreto en un fichero de `openspec/` después de una verificación verde
- **THEN** la firma sigue valiendo y ese commit pasa, porque la huella no cubre `openspec/`
- **AND** la siguiente verificación lo caza, porque el escaneo de secretos sí mira ahí

#### Scenario: Alguien desactiva ATS

- **WHEN** aparece `NSAppTransportSecurity` en el `Info.plist` o en la fuente que lo genera
- **THEN** la verificación sale en rojo, aunque el código siga compilando y los tests verdes

#### Scenario: El plist deja de ser XML

- **WHEN** el `Info.plist` se guarda en formato binario, como hace Xcode a veces
- **THEN** la comprobación lo sigue leyendo, en vez de pasar en verde sin mirar

#### Scenario: La lista de invariantes y lo que la comprueba discrepan

- **WHEN** un invariante está escrito pero nada lo comprueba, o una comprobación bloquea algo
  que no está en la lista
- **THEN** se corrige la lista o la comprobación, por escrito, antes de seguir
