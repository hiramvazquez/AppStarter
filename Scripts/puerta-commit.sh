#!/usr/bin/env bash
# Hook PreToolUse — el ÚNICO que bloquea, porque es el único evento de Claude Code que
# puede. Si el comando es un `git commit`, exige que exista firma de verificación para
# ESTE diff.
#
# Por qué este y no otros: sin él, "los tests pasan" es una afirmación del modelo sobre un
# árbol que pudo cambiar después de correrlos. Es error de proceso, no mala fe, y es el
# fallo que más caro sale porque no deja rastro.
#
# Límite declarado: frena el olvido, no a alguien decidido a saltárselo (`--no-verify`,
# otra terminal, un `git` invocado de otra forma). Eso no se puede cerrar desde dentro de
# la misma máquina, y fingir lo contrario es peor que no tenerlo.
set -uo pipefail
cd "$(git rev-parse --show-toplevel 2>/dev/null)" || exit 0

CMD="$(python3 -c 'import json,sys; print(json.load(sys.stdin).get("tool_input",{}).get("command",""))' 2>/dev/null)"
case "$CMD" in
  *"git commit"*) ;;
  *) exit 0 ;;
esac

if bash Scripts/verifica.sh --comprueba >/dev/null 2>&1; then
    exit 0
fi

python3 - <<'PY'
import json
print(json.dumps({"hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "deny",
    "permissionDecisionReason": (
        "No hay verificación firmada para este diff. Corre `bash Scripts/verifica.sh` y "
        "commitea después, en un comando aparte — encadenar `git add && git commit` "
        "cambia el diff entre la firma y el commit."
    )}}))
PY
