# Red team / explotación
# metasploit: BSD-3, está en nixpkgs.
# impacket: solo existe como paquete Python en nixpkgs → se envuelve en
#   python3.withPackages para exponer sus scripts de CLI.
# responder, netexec, bloodhound: hueco conocido de nixpkgs → apt en runtime
# (documentado en toolchain-matrix.md). Aquí solo lo empaquetado.
{ pkgs }:
with pkgs;
[
  metasploit
  (python3.withPackages (ps: [ ps.impacket ]))
  evil-winrm
  chisel
]
