# Helper genérico de imágenes secforge.
#
# Decisiones críticas (ver docs/TROUBLESHOOTING.md):
# - extraPrefix = "/usr": la base es Debian usr-merged (/bin → /usr/bin).
#   Sin esto, la capa Nix pisaría el /bin de Kali y rompería TODA la base
#   (nixpkgs issue #240919). Con extraPrefix, el overlayfs fusiona /usr/bin
#   (directorio con directorio) en lugar de pisar el symlink.
# - De la imagen base solo se hereda Env → definimos Cmd y Env explícitos.
# - Los binarios nixpkgs viven en /nix/store dentro de la imagen; /usr/bin
#   contiene symlinks hacia ellos. Son autocontenidos: no chocan con la glibc
#   de Kali.
{
  pkgs,
  kaliBase,
  name,
  presetPaths,
  tag ? "nix",
  extraEnv ? [ ],
}:
let
  tools = pkgs.buildEnv {
    name = "${name}-tools";
    extraPrefix = "/usr";
    paths = presetPaths;
    pathsToLink = [
      "/bin"
      "/share"
    ];
  };
in
pkgs.dockerTools.buildImage {
  inherit name tag;
  fromImage = kaliBase;
  copyToRoot = tools;
  config = {
    Cmd = [ "/bin/bash" ];
    Env = [
      "PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
    ]
    ++ extraEnv;
  };
}
