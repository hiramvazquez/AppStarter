#!/usr/bin/env python3
"""Caza lógica repetida: el mismo cuerpo de función escrito en dos sitios.

El caso real que motiva esto: tres `extension Date` en tres view models distintos
haciendo lo mismo. Ningún linter lo ve —cada una es correcta por separado— y ninguna
review lo caza, porque el revisor mira UN diff y las tres nacieron en semanas distintas.

Qué hace: extrae cada `func`/`var` computada con cuerpo, lo normaliza (fuera comentarios,
espacios y el nombre propio) y agrupa por huella. Dos cuerpos idénticos en ficheros
distintos son un duplicado; en el mismo fichero, no (sobrecargas legítimas).

Y aparte: agrupa las `extension` del MISMO tipo declaradas en módulos distintos, que es
la forma que toma el problema antes de que los cuerpos sean idénticos.

Uso:  python3 Scripts/busca-duplicados.py [rutas...]   (por defecto: App y Packages)
Sale 1 si encuentra algo; 0 si está limpio.
"""
import hashlib, re, sys
from collections import defaultdict
from pathlib import Path

RAICES = [Path(p) for p in (sys.argv[1:] or ["App", "Packages"])]
MIN_LINEAS = 3  # un cuerpo de 1-2 líneas coincide por casualidad demasiado a menudo

def sin_ruido(txt):
    txt = re.sub(r"//[^\n]*", "", txt)
    txt = re.sub(r"/\*.*?\*/", "", txt, flags=re.S)
    return re.sub(r"\s+", " ", txt).strip()

def cuerpos(ruta):
    """(nombre, huella, línea, nº de líneas) por cada func/var con cuerpo."""
    src = ruta.read_text(errors="replace")
    for m in re.finditer(r"\b(?:func|var)\s+(\w+)[^\n{]*\{", src):
        i = src.index("{", m.end() - 1)
        prof, j = 0, i
        while j < len(src):
            if src[j] == "{": prof += 1
            elif src[j] == "}":
                prof -= 1
                if prof == 0: break
            j += 1
        cuerpo = src[i + 1:j]
        n = cuerpo.count("\n")
        if n < MIN_LINEAS: continue
        norm = sin_ruido(cuerpo)
        if len(norm) < 60: continue
        yield m.group(1), hashlib.sha1(norm.encode()).hexdigest()[:10], src[:m.start()].count("\n") + 1, n

def extensiones(ruta):
    for m in re.finditer(r"^\s*(?:public\s+|internal\s+)?extension\s+(\w+)", ruta.read_text(errors="replace"), re.M):
        yield m.group(1), ruta.name

ficheros = sorted({f for r in RAICES for f in r.rglob("*.swift")
                   if ".build" not in f.parts and "checkouts" not in f.parts})
por_huella, por_tipo = defaultdict(list), defaultdict(set)
for f in ficheros:
    for nombre, h, linea, n in cuerpos(f):
        por_huella[h].append((f, nombre, linea, n))
    for tipo, nom in extensiones(f):
        por_tipo[tipo].add(str(f))

fallos = 0
dups = {h: v for h, v in por_huella.items() if len({x[0] for x in v}) > 1}
if dups:
    fallos += len(dups)
    print(f"❌ {len(dups)} cuerpo(s) repetido(s) en ficheros distintos:\n")
    for h, apar in sorted(dups.items(), key=lambda kv: -kv[1][0][3]):
        print(f"  huella {h} — {apar[0][3]} líneas, {len(apar)} copias:")
        for f, nombre, linea, _ in apar:
            print(f"     {f}:{linea}  {nombre}()")
        print()

esparcidas = {t: fs for t, fs in por_tipo.items() if len(fs) > 2}
if esparcidas:
    print(f"⚠️  tipos extendidos desde 3+ ficheros (mírales antes de que converjan):\n")
    for t, fs in sorted(esparcidas.items(), key=lambda kv: -len(kv[1])):
        print(f"  extension {t} — {len(fs)} ficheros")
        for f in sorted(fs): print(f"     {f}")
        print()

if not fallos and not esparcidas:
    print(f"✅ sin lógica repetida en {len(ficheros)} ficheros Swift.")
sys.exit(1 if fallos else 0)
