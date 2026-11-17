# Contraseñas y autenticación
# hashcat funciona en modo CPU dentro del contenedor (sin GPU no habrá OpenCL acelerado).
{ pkgs }:
with pkgs;
[
  hashcat
  john
  thc-hydra
  medusa
  fcrackzip
  crunch
]
