# Aplicaciones web
# burpsuite es unfree (permitido explícitamente en flake.nix).
{ pkgs }:
with pkgs;
[
  sqlmap
  nikto
  ffuf
  dirb
  wpscan
  mitmproxy
  gobuster
  wfuzz
  commix
  burpsuite
]
