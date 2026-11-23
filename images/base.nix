# Base Kali Linux anclada por digest — REPRODUCIBILIDAD GARANTIZADA.
#
# ACTUALIZAR (solo vía PR automático digest-update.yml o manualmente):
#   nix run nixpkgs#nix-prefetch-docker -- \
#     --image-name kalilinux/kali-rolling --image-tag latest --arch amd64 --os linux
#
# Gotcha conocido: nix-prefetch-docker a veces devuelve un hash incorrecto;
# si el build falla con "invalid hash", copiar el hash EXACTO que Nix sugiere
# en el mensaje de error (ver docs/TROUBLESHOOTING.md).
#
# Estado: anclado al snapshot semanal del 2026-11-16 (digest 1ff4a2be...).
{ pkgs }:
pkgs.dockerTools.pullImage {
  imageName = "kalilinux/kali-rolling";
  imageDigest = "sha256:69a9a33d98a584a537bd0f7144d20c3b6d23f3bafa9ffcf0cadf4c5f186d02ff";
  sha256 = "sha256-ftPfLOmKHCStEnWQEa6cEh34K+6MBy38GDWF34LcZGc=";
  finalImageName = "kali";
  finalImageTag = "pinned";
}
