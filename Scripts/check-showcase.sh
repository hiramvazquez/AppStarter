#!/bin/bash
# Verifies the "Escaparate" table in README.md (PRD-APP-02, Fase 3): every citation of the
# form `Symbol` en `path/to/File.swift:NN` must point at a file that actually exists, at a
# line where — within NN±3 — `Symbol` (a literal, fixed-string match, not a regex) really
# appears. Run from the repo root; exits non-zero (and lists every broken citation) on the
# first pass over the whole table, not just the first failure — one CI run should tell you
# everything that's wrong, not one row at a time.
set -uo pipefail

cd "$(dirname "$0")/.."
readonly README="README.md"

if [ ! -f "$README" ]; then
    echo "check-showcase.sh: no se encontró $README" >&2
    exit 1
fi

# Extracts every `Symbol` en `file:line` citation from the README's escaparate section —
# the format every row of the two PRD-APP-02 tables uses (see README.md § Escaparate).
# One match per line: SYMBOL<TAB>FILE<TAB>LINE. `perl -0777` (whole file, `\s` spans
# newlines) on purpose: markdown hard-wraps long bullets, so a citation's closing
# `` `file:line` `` often lands on the line AFTER its opening `` `Symbol` `` — a
# single-line `grep -oE` would silently skip every wrapped citation.
citations=$(perl -0777 -ne '
    while (/`([^`]+)`\s+en\s+`([^`]+):([0-9]+)(?:-[0-9]+)?`/gs) {
        my ($symbol, $file, $line) = ($1, $2, $3);
        # Markdown hard-wraps mid-citation sometimes (a `Symbol` or `file:line` span
        # itself broken across two lines) — collapse any embedded whitespace/newlines to
        # a single space so this prints as ONE clean tab-separated record; an un-collapsed
        # newline here would make the `while read` loop below see it as two records.
        $symbol =~ s/\s+/ /g;
        $file =~ s/\s+/ /g;
        print "$symbol\t$file\t$line\n";
    }
' "$README")

if [ -z "$citations" ]; then
    echo "check-showcase.sh: no se encontró ninguna cita 'Símbolo' en 'fichero:línea' en $README" >&2
    exit 1
fi

total=0
failures=0
declare -a failure_messages=()

while IFS=$'\t' read -r symbol file line; do
    [ -z "$symbol" ] && continue
    total=$((total + 1))

    if [ ! -f "$file" ]; then
        failures=$((failures + 1))
        failure_messages+=("MISSING FILE: \`$symbol\` → $file:$line (el fichero no existe)")
        continue
    fi

    file_lines=$(wc -l < "$file" | tr -d ' ')
    if [ "$line" -gt "$file_lines" ]; then
        failures=$((failures + 1))
        failure_messages+=("LINE OUT OF RANGE: \`$symbol\` → $file:$line ($file solo tiene $file_lines líneas)")
        continue
    fi

    start=$((line - 3))
    [ "$start" -lt 1 ] && start=1
    end=$((line + 3))

    window=$(sed -n "${start},${end}p" "$file")
    if ! grep -qF -- "$symbol" <<<"$window"; then
        failures=$((failures + 1))
        failure_messages+=(
            "SYMBOL NOT FOUND: \`$symbol\` no aparece en $file:${start}-${end} (línea citada: $line)"
        )
    fi
done <<<"$citations"

echo "check-showcase.sh: $total citas verificadas, $failures fallo(s)."

if [ "$failures" -gt 0 ]; then
    echo "" >&2
    echo "Citas rotas:" >&2
    for message in "${failure_messages[@]}"; do
        echo "  - $message" >&2
    done
    exit 1
fi

exit 0
