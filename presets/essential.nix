# Núcleo de auditoría presente en TODAS las imágenes (equivalente ligero de kali-linux-headless).
# Origen: nixpkgs nativo. Ver docs/toolchain-matrix.md para justificación por herramienta.
{ pkgs }:
with pkgs;
[
  nmap
  tcpdump
  curl
  wget
  git
  jq
  socat
  netcat
  whois
  traceroute
  bind # dig, nslookup
  openssh
  file
  unzip
]
