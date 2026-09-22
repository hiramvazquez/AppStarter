## ADDED Requirements

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

Estas comprobaciones son de TEXTO, no de semántica, y el alcance de cada una MUST estar
escrito donde vive la comprobación. Hoy: el almacén de credenciales se detecta por el NOMBRE
del fichero —sesión, token, credencial, keychain—, así que uno llamado de otra forma se
escapa; las URLs se detectan en literales de una línea, así que una construida por concatenación o
escrita dentro de un string multilínea se escapa;
y el escaneo de secretos no ve un fichero que no pueda leer. Se aceptan porque el caso que
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

#### Scenario: La lista de invariantes y lo que la comprueba discrepan

- **WHEN** un invariante está escrito pero nada lo comprueba, o una comprobación bloquea algo
  que no está en la lista
- **THEN** se corrige la lista o la comprobación, por escrito, antes de seguir

### Requirement: Las excepciones a un invariante se declaran donde se ven

Un invariante que este proyecto incumple a propósito SHALL quedar declarado junto a la
comprobación que lo detecta, nombrando el sitio exacto y el motivo. NOT MUST silenciarse
bajando la severidad, quitando la regla, ni con una desactivación suelta en el fichero
afectado.

Hoy hay exactamente una: `UserDefaultsSessionStore` guarda el bearer token en `UserDefaults`,
por la decisión de plantilla de PRD-APP-01 —poder clonar y correr sin aprovisionar Keychain—.

#### Scenario: Aparece un segundo almacén de credenciales sobre UserDefaults

- **WHEN** se añade otro almacén de credenciales sobre `UserDefaults` en un fichero cuyo nombre
  nombra sesión, token, credencial o keychain
- **THEN** la verificación sale en rojo, porque la excepción declarada es solo la existente
- **AND** si el fichero se llama de otra forma, la comprobación no lo ve: eso lo cubre el
  revisor, y está dicho arriba

#### Scenario: La excepción deja de hacer falta

- **WHEN** el almacén de sesión pasa a Keychain
- **THEN** basta retirar la excepción declarada, sin tocar la regla

### Requirement: Las dependencias se revisan contra vulnerabilidades conocidas

El CI SHALL comprobar los `Package.resolved` del proyecto contra una base de vulnerabilidades
conocidas, y SHALL fallar si alguna dependencia tiene un aviso. Esa comprobación NOT MUST
correr en cada verificación local: lo que cambia no es el código del repositorio, sino los
avisos publicados.

#### Scenario: Una dependencia acumula un aviso conocido

- **WHEN** una dependencia declarada tiene una vulnerabilidad publicada
- **THEN** el job de dependencias del CI falla y la nombra

#### Scenario: Se verifica en local

- **WHEN** alguien corre `/kit-verifica`
- **THEN** no se consulta ninguna base de vulnerabilidades ni se sale a la red por ello
