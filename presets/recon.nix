# Reconocimiento / OSINT
# NOTA: theharvester y maltego no están (o no se confirmó que estén) en nixpkgs
# → instalarlos en runtime con apt (kali-rolling) o descartar. Ver toolchain-matrix.md.
{ pkgs }:
with pkgs;
[
  amass
  whatweb
  subfinder
]
