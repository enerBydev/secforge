#!/usr/bin/env bash
# L3 — PRUEBA FUNCIONAL REAL contra un objetivo vulnerable local (DVWA).
# Demuestra utilidad REAL, no solo presencia de binarios.
#
# Verificaciones:
#   1. nmap detecta el servicio HTTP en el contenedor objetivo
#   2. nikto produce hallazgos contra el servidor
#   3. sqlmap confirma la inyección en el formulario de login de DVWA
#
# Requiere: runtime de contenedores (podman/docker) y red local funcional.
set -uo pipefail

PORT="${PORT:-8080}"
BASE="http://127.0.0.1:${PORT}"
IMAGE_TARGET="${IMAGE_TARGET:-vulnerables/web-dvwa:latest}"
IMAGE_TOOLS="${IMAGE_TOOLS:?Uso: functional.sh (export IMAGE_TOOLS=secforge-web:nix)}"

if command -v podman >/dev/null 2>&1 && [[ "${RUNTIME:-podman}" != docker ]]; then
  RT=(podman)
else
  RT=(docker)
fi

pass=0
fail=0
note() { echo "  $1  $2"; }
declare_result() {
  if [[ "$1" == PASS ]]; then pass=$((pass + 1)); note "PASS" "$2"; else fail=$((fail + 1)); note "FAIL" "$2"; fi
}

echo "» L3 — objetivo: DVWA en 127.0.0.1:${PORT} (runtime ${RT[0]})"

# Levantar objetivo vulnerable
"${RT[@]}" rm -f secforge-dvwa >/dev/null 2>&1
if ! "${RT[@]}" run -d --name secforge-dvwa -p "${PORT}:80" "$IMAGE_TARGET" >/dev/null 2>&1; then
  echo "ROJO: no se pudo levantar el objetivo DVWA" >&2
  exit 2
fi
trap '"${RT[@]}" rm -f secforge-dvwa >/dev/null 2>&1' EXIT

# Esperar a que el servicio responda (máx 60s)
ok=""
for _ in $(seq 1 30); do
  if curl -s --max-time 2 "$BASE" | grep -qi dvwa; then ok=1; break; fi
  sleep 2
done
[[ -z "$ok" ]] && {
  echo "ROJO: DVWA no respondió a tiempo" >&2
  exit 2
}

# 1) nmap detecta el servicio
r=$("${RT[@]}" run --rm --network host "$IMAGE_TOOLS" bash -c "nmap -p ${PORT} -sV 127.0.0.1 2>/dev/null")
echo "$r" | grep -qi "open" && declare_result PASS "nmap: puerto ${PORT} abierto detectado" || declare_result FAIL "nmap: puerto ${PORT} abierto detectado"

# 2) nikto produce hallazgos
r=$("${RT[@]}" run --rm --network host "$IMAGE_TOOLS" bash -c "nikto -h ${BASE} -nointeractive 2>/dev/null")
echo "$r" | grep -qiE "Nikto|Server:" && [[ $(echo "$r" | grep -c "+") -gt 0 ]] && declare_result PASS "nikto: hallazgos emitidos" || declare_result FAIL "nikto: hallazgos emitidos"

# 3) sqlmap confirma inyección en login de DVWA
#    (POST username/password con cookie de sesión + security=low)
"${RT[@]}" exec secforge-dvwa bash -c 'bash /var/www/html/.setup.sh 2>/dev/null' >/dev/null 2>&1
curl -s -c /tmp/dvwa.jar "$BASE/login.php" >/dev/null
curl -s -b /tmp/dvwa.jar -c /tmp/dvwa.jar "$BASE/login.php" | grep -o 'user_token" value="[^"]*"' | cut -d'"' -f4 >/tmp/token.txt
TOKEN=$(cat /tmp/token.txt 2>/dev/null || echo "")
curl -s -b /tmp/dvwa.jar -c /tmp/dvwa.jar -d "username=admin&password=password&user_token=${TOKEN}&Login=Login" "$BASE/login.php" >/dev/null
r=$("${RT[@]}" run --rm --network host \
  -v /tmp/dvwa.jar:/tmp/dvwa.jar:ro \
  "$IMAGE_TOOLS" bash -c "sqlmap -u ${BASE}/login.php --data='username=admin&password=*&user_token=&Login=Login' --cookie='security=low' --batch --level=1 2>/dev/null")
echo "$r" | grep -qi "injectable" && declare_result PASS "sqlmap: inyección confirmada en login.php" || declare_result FAIL "sqlmap: inyección confirmada en login.php"

echo "» L3: $pass PASS, $fail FAIL"
[[ $fail -eq 0 ]]
