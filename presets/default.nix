# Carga todos los presets con una única instancia de pkgs.
# Cada preset es un fichero que recibe { pkgs } y devuelve una lista de paquetes.
{ pkgs }:
let
  load = f: import f { inherit pkgs; };
in
{
  essential = load ./essential.nix;
  network = load ./network.nix;
  web = load ./web.nix;
  password = load ./password.nix;
  recon = load ./recon.nix;
  forensics = load ./forensics.nix;
  blueteam = load ./blueteam.nix;
  redteam = load ./redteam.nix;
}
