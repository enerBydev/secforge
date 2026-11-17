# Red team / explotación
# metasploit: BSD-3, está en nixpkgs.
# responder, netexec, bloodhound: hueco conocido de nixpkgs → apt en runtime
# (documentado en toolchain-matrix.md). Aquí solo lo empaquetado.
{ pkgs }:
with pkgs;
[
  metasploit
  impacket
  evil-winrm
  chisel
]
