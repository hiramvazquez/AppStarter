## 1. La comprobación

- [x] 1.1 Paso `ATS` en `kit.conf`: falla si `NSAppTransportSecurity` aparece en `project.yml`
      o en cualquier `Info.plist` versionado. El plist se lee con `plutil`, que entiende XML y
      binario. Verificación: el paso sale verde en el árbol actual.
      **Hecho:** paso `ATS`, el primero junto al de secretos. Mira `project.yml` con `grep` y todos los `Info.plist` que git versiona con `plutil -p`. Verde en el árbol actual.

## 2. Que falle cuando toca

- [x] 2.1 Con la clave en `project.yml`: el paso se pone rojo. Verificación: el código de
      salida y el mensaje, anotados, y el fichero devuelto a su sitio.
      **Hecho:** con `NSAppTransportSecurity: {NSAllowsArbitraryLoads: true}` en el `info.properties` de `project.yml`, sale 1 y dice «project.yml declara NSAppTransportSecurity». Restaurado.
- [x] 2.2 Con la clave en `App/Info.plist`: el paso se pone rojo. Verificación: lo mismo.
      **Hecho:** con la clave insertada en el plist XML, sale 1 y nombra el fichero. Restaurado.
- [x] 2.3 Con el plist convertido a BINARIO y la clave dentro: el paso lo sigue viendo. Es la
      razón de usar `plutil` y no `grep`, así que sin este caso la decisión no está fijada.
      Verificación: el código de salida, anotado, y el plist devuelto a XML.
      **Hecho, y es el caso que justifica la decisión:** convertido el plist a binario con `plutil -convert binary1` —`file` confirma «Apple binary property list»—, el paso lo sigue viendo y sale 1. Con `grep` habría pasado en verde sin mirar. Plist devuelto a XML.

## 3. El acuerdo

- [x] 3.1 `AGENTS.md`: la fila del séptimo invariante en la tabla, y fuera la frase que decía
      que nadie comprueba el `Info.plist`. Verificación: esa frase ya no está.
      **Hecho:** fila nueva en la tabla, y fuera la frase «Nada comprueba hoy App/Info.plist». En su lugar, cómo se comprueba y por qué con `plutil`.

## 4. Cierre

- [x] 4.1 `openspec validate ats-no-se-desactiva-en-silencio --strict` en verde.
      **Hecho:** `Change 'ats-no-se-desactiva-en-silencio' is valid`.
- [x] 4.2 `/kit-revisa`. Presupuesto: una ronda. Atención a lo de siempre en estas reglas: qué
      se le escapa y qué bloquearía de más.
      **Ronda 1 (2026-09-22): AMBER**, cinco hallazgos, todos reproducidos, y el primero era
      el mismo agujero que el comentario del paso decía estar tapando:
      - **El paso pasaba en VERDE si `plutil` fallaba**, porque el estado de salida era el del
        `grep` de la tubería. Con un plist truncado y la clave dentro, con `plutil` ausente o
        con el fichero sin permisos: verde. Arreglado capturando la salida y fallando cerrado.
      - **`set -e` no protegía ningún camino**: las tres órdenes que podían fallar estaban en
        condiciones de `if` o en la lista de un `for`. Con `git ls-files` abortando, el paso
        afirmaba que no había plists.
      - **Miraba el ÍNDICE y no el árbol**, así que se le escapaban: un plist con otro nombre,
        uno todavía sin stagear —y la firma tampoco lo delataba, porque es una foto del árbol
        y el fichero ya estaba dentro: huella idéntica antes y después del `git add`— y una
        ruta con espacios, que el `for` partía por palabras. Ahora recorre el árbol con
        `find -print0`.
      - **Falso rojo** si alguien nombraba la clave en un comentario de `project.yml`.
        Arreglado con `^[^#]*`.
      - La spec metía lo de «vigila la clave entera» en el párrafo de lo que se escapa, cuando
        es lo contrario. Corregido, y añadido el límite real: un `xcconfig` queda fuera.
      Comprobado después con cinco casos: plist truncado, clave en comentario, plist con otro
      nombre, plist sin stagear y con espacio en la ruta, y árbol limpio.
      **Se cierra en una ronda**, que es el presupuesto: los arreglos son del paso, no del
      acuerdo, y cada uno tiene su caso medido.
- [x] 4.3 `/kit-verifica` en verde. Verificación: la firma y cuánto añade el paso.
      **Hecho (2026-09-22):** verde con `✅ ATS` dentro. El paso tarda 26 ms sobre los dos
      plists del árbol, así que la verificación sigue en unos 64 s.
