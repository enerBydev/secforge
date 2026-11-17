# Helper genérico de imágenes secforge.
#
# Decisiones críticas (ver docs/TROUBLESHOOTING.md):
# - buildLayeredImage (NO buildImage): buildImage (legacy) produjo capas
#   grandes (~2 GB, preset redteam/metasploit) con diffID no determinista —
#   `docker load` fallaba con "invalid diffID" y el digest cambiaba entre
#   rebuilds. buildLayeredImage calcula diffIDs correctamente, es el builder
#   mantenido y soporta fromImage (PR nixpkgs #115857).
# - Las herramientas NIX viven en /nix/store y se exponen SOLO vía PATH
#   (${tools}/bin primero). NO se escriben symlinks en /usr/bin de la base:
#   eso elimina de raíz el problema usr-merge de Debian (nixpkgs #240919)
#   y la base Kali queda intacta por construcción.
# - De la imagen base solo se hereda Env → definimos Cmd y Env explícitos.
# - Orden PATH: herramientas nix primero (misma precedencia que tenía el
#   overlay extraPrefix=/usr), luego las nativas de Kali (apt en runtime).
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
    paths = presetPaths;
    # Solo /bin: las man pages no son necesarias para v0.1 y cada top-level
    # de pathsToLink acaba en la RAÍZ del layer (ver fakeRootCommands).
    pathsToLink = [ "/bin" ];
  };
in
pkgs.dockerTools.buildLayeredImage {
  inherit name tag;
  fromImage = kaliBase;
  contents = [ tools ];
  # GOTCHA (docs/TROUBLESHOOTING.md #5): buildLayeredImage fusiona `contents`
  # en la raíz del layer vía symlinkJoin → crea un /bin REAL que tapa el
  # symlink usr-merge /bin → /usr/bin de la base Debian/Kali y rompe
  # /bin/sh. Se restaura el symlink dentro del propio layer: la base queda
  # intacta y las herramientas se exponen SOLO por PATH (nix store).
  fakeRootCommands = ''
    rm -rf bin
    ln -s /usr/bin bin
  '';
  config = {
    Cmd = [ "/bin/bash" ];
    Env = [
      "PATH=${tools}/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
    ]
    ++ extraEnv;
  };
}
