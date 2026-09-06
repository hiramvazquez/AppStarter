#!/usr/bin/env bash
# Corre la verificación del proyecto y FIRMA que corrió contra ESTE diff.
#
# El marker liga el resultado al `sha256` del diff staged. Sin eso, "los tests pasan" es una
# afirmación del modelo sobre un árbol que pudo cambiar después — el fallo de proceso más
# común y el más difícil de ver a posteriori. Con el marker, o la firma casa con lo que vas
# a commitear, o no casa.
#
# Uso:
#   Scripts/verifica.sh              # verifica y firma
#   Scripts/verifica.sh --informe    # solo imprime el último informe, sin volver a correr
#   Scripts/verifica.sh --comprueba  # ¿hay firma válida para el diff staged? (exit 1 si no)
set -uo pipefail
cd "$(git rev-parse --show-toplevel)" || exit 1
MARKER=".claude/estado/verificacion.txt"
mkdir -p "$(dirname "$MARKER")"
huella() { git diff --cached | shasum -a 256 | cut -d' ' -f1; }

case "${1:-}" in
--informe)
    [ -f "$MARKER" ] && cat "$MARKER" || echo "sin informe: no se ha corrido Scripts/verifica.sh"
    exit 0 ;;
--comprueba)
    [ -f "$MARKER" ] || { echo "❌ nada verificado todavía"; exit 1; }
    grep -q "^diff: $(huella)$" "$MARKER" \
        && { echo "✅ firma válida para el diff staged"; exit 0; } \
        || { echo "❌ la firma es de OTRO diff — vuelve a correr Scripts/verifica.sh"; exit 1; }
    ;;
esac

FALLOS=0
INFORME=""
paso() {  # paso <nombre> <comando...>
    local n="$1"; shift
    printf '▶ %s\n' "$n"
    if out=$("$@" 2>&1); then
        INFORME="${INFORME}✅ ${n}"$'\n'
    else
        INFORME="${INFORME}❌ ${n}"$'\n'"$(printf '%s\n' "$out" | tail -15)"$'\n'
        FALLOS=$((FALLOS+1))
    fi
}

paso "Platform · build"  bash -c 'cd Packages/Platform && swift build'
paso "Platform · tests"  bash -c 'cd Packages/Platform && swift test'
paso "Features · build"  bash -c 'cd Packages/Features && swift build'
paso "Features · tests"  bash -c 'cd Packages/Features && swift test'

# Duplicación: no es un lint más, es la única clase que ya nos mordió tres veces (tres
# `extension Date` en tres view models). Avisa, no bloquea — un duplicado puede ser
# deliberado, y quien lo decide es el juez de aceptación con el cambio delante.
printf '▶ %s\n' "lógica repetida"
DUP="$(python3 Scripts/busca-duplicados.py 2>&1)"
case "$DUP" in
  *"sin lógica repetida"*) INFORME="${INFORME}✅ lógica repetida: ninguna"$'\n' ;;
  *) INFORME="${INFORME}⚠️  lógica repetida (mírala, no bloquea):"$'\n'"${DUP}"$'\n' ;;
esac

{
    echo "verificado: $(date -u +%FT%TZ)"
    echo "diff: $(huella)"
    echo "rama: $(git rev-parse --abbrev-ref HEAD)"
    echo
    printf '%s' "$INFORME"
} > "$MARKER"

printf '%s' "$INFORME"
[ "$FALLOS" -eq 0 ] && echo "✅ verificación en verde, firmada contra el diff staged." \
                    || echo "❌ $FALLOS paso(s) en rojo — sin firma útil."
exit "$FALLOS"
