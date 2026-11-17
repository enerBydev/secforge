#!/usr/bin/env bash
# Orquestador de la suite completa: imprime reporte PASS/FAIL por nivel.
# Rojo si CUALQUIER nivel falla.
#
# Uso: tests/run-all.sh [L0|L2|L3|all]
set -uo pipefail
cd "$(dirname "$0")/.."

LEVEL="${1:-all}"
overall=0
declare -a results

run() {
  local label="$1"
  shift
  echo ""
  echo "══════════ $label ══════════"
  if "$@"; then results+=("PASS  $label"); else results+=("FAIL  $label"); overall=1; fi
}

if [[ "$LEVEL" == "L0" || "$LEVEL" == "all" ]]; then
  run "L0 flake check" nix flake check
fi

if [[ "$LEVEL" == "L2" || "$LEVEL" == "all" ]]; then
  for manifest in tests/smoke/*.tsv; do
    variant="$(basename "$manifest" .tsv)"
    [[ "$variant" == "full" ]] && continue  # full se cubre por sus variantes
    run "L2 smoke $variant" bash tests/smoke.sh "localhost/secforge-${variant}:nix" "$manifest"
  done
fi

if [[ "$LEVEL" == "L3" || "$LEVEL" == "all" ]]; then
  run "L3 funcional (DVWA)" bash tests/functional.sh
fi

echo ""
echo "══════════ RESUMEN ══════════"
printf '%s\n' "${results[@]:-sin pruebas ejecutadas}"
[[ $overall -eq 0 ]] && echo "» VERDE: todo en orden" || echo "» ROJO: hay fallos — revisar arriba"
exit $overall
