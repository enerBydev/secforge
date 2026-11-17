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
  imageDigest = "sha256:1ff4a2be3849333687b3ed2b31bb5af0cd1b7c0a11ec7713feb5abe5a6b2795c";
  sha256 = "sha256-jXucMJETjUoxXa3FA+b6CDOH8xT9GDD6S+ztrNp8ZFU=";
  finalImageName = "kali";
  finalImageTag = "pinned";
}
