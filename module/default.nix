# Módulo NixOS: estación de trabajo de pentesting declarativa.
#
# Uso en configuration.nix del host:
#   imports = [ secforge.nixosModules.default ];
#   secforge.pentesting = {
#     enable = true;
#     categories = {
#       network = true;
#       web = true;
#       # ... el resto, false por defecto
#     };
#   };
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.secforge.pentesting;
  presets = import ../presets { inherit pkgs; };
in
{
  options.secforge.pentesting = {
    enable = lib.mkEnableOption "toolchain de ciberseguridad secforge";

    categories = lib.mkOption {
      description = "Qué presets de herramientas instalar en el sistema";
      type = lib.types.attrsOf lib.types.bool;
      default = {
        essential = true;
        network = false;
        web = false;
        password = false;
        recon = false;
        forensics = false;
        blueteam = false;
        redteam = false;
      };
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = lib.flatten (
      lib.mapAttrsToList (name: enabled: lib.optional enabled presets.${name}) cfg.categories
    );
  };
}
