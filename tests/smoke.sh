#!/usr/bin/env bash
# L2 — SMOKE TEST: verifica que cada herramienta declarada en una imagen
# responde. PASS = que el binario exista Y ejecute. NO demuestra utilidad
# (eso es L3, ver functional.sh).
#
# Uso:  tests/smoke.sh <imagen:tag> <tests/smoke/<variante>.tsv>
#       (RUNTIME=docker para forzar Docker; por defecto detecta podman)
set -uo pipefail

IMAGE="${1:?Uso: smoke.sh <imagen:tag> <manifest.tsv>}"
MANIFEST="${2:?Uso: smoke.sh <imagen:tag> <manifest.tsv>}"

if command -v podman >/dev/null 2>&1 && [[ "${RUNTIME:-podman}" != docker ]]; then
  RT=(podman)
else
  RT=(docker)
fi
echo "» Runtime: ${RT[0]} | Imagen: $IMAGE"

if [[ ! -f "$MANIFEST" ]]; then
  echo "ROJO: manifest no encontrado: $MANIFEST" >&2
  exit 2
fi

pass=0
fail=0
while IFS=$'\t' read -r tool check; do
  [[ -z "$tool" || "$tool" =~ ^# ]] && continue
  if "${RT[@]}" run --rm "$IMAGE" bash -c "$check" >/dev/null 2>&1; then
    echo "  PASS  $tool"
    pass=$((pass + 1))
  else
    echo "  FAIL  $tool  (check: $check)"
    fail=$((fail + 1))
  fi
done <"$MANIFEST"

echo "» $IMAGE: $pass PASS, $fail FAIL"
# Rojo si CUALQUIER herramienta falla — cero excepciones silenciosas.
[[ $fail -eq 0 ]]
