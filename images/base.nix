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
# Estado actual: PLACEHOLDER — el primer build fallará por diseño hasta que
# se peguen los valores reales (flujo de bootstrap documentado en README).
{ pkgs }:
pkgs.dockerTools.pullImage {
  imageName = "kalilinux/kali-rolling";
  imageDigest = "sha256:BOOTSTRAP_DIGEST_REEMPLAZAR";
  sha256 = "sha256-BOOTSTRAP_HASH_REEMPLAZAR";
  finalImageName = "kali";
  finalImageTag = "pinned";
}
