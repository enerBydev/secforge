{
  description = "secforge — toolchains de ciberseguridad sobre base Kali anclada (imágenes Docker + devShells + módulo NixOS)";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs =
    { self, nixpkgs }:
    let
      # Paquetes unfree permitidos — lista EXPLÍCITA y auditable (ver docs/LICENSES.md).
      # No usar allowUnfree = true global.
      unfreeAllowed = [
        "burpsuite"
        "maltego"
      ];

      mkPkgs =
        system:
        import nixpkgs {
          inherit system;
          config.allowUnfreePredicate =
            pkg: builtins.elem (nixpkgs.lib.getName pkg) unfreeAllowed;
        };

      # Las imágenes se anclan a un digest amd64 concreto → solo x86_64-linux.
      # Los devShells y presets también sirven en aarch64-linux.
      shellSystems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      imageSystems = [ "x86_64-linux" ];
    in
    {
      # Listas de herramientas por categoría, expuestas para reutilización.
      presets = nixpkgs.lib.genAttrs shellSystems (
        system: import ./presets { pkgs = mkPkgs system; }
      );

      devShells = nixpkgs.lib.genAttrs shellSystems (
        system:
        let
          pkgs = mkPkgs system;
          presets = import ./presets { pkgs = pkgs; };
        in
        presets
        // {
          # Shell de mantenimiento del propio repo
          dev = pkgs.mkShell {
            packages = with pkgs; [
              nix-prefetch-docker
              skopeo
            ];
          };
        }
      );

      formatter = nixpkgs.lib.genAttrs shellSystems (system: (mkPkgs system).nixfmt-rfc-style);

      packages = nixpkgs.lib.genAttrs imageSystems (
        system:
        let
          pkgs = mkPkgs system;
          lib = pkgs.lib;
          presets = import ./presets { pkgs = pkgs; };
          kaliBase = import ./images/base.nix { inherit pkgs; };
          mkImage =
            {
              name,
              presetPaths,
            }:
            import ./images/mkImage.nix {
              inherit pkgs;
              kaliBase = kaliBase;
              inherit name presetPaths;
            };
          combine = names: lib.concatLists (map (n: presets.${n}) names);
          allCategories = [
            "essential"
            "network"
            "web"
            "password"
            "recon"
            "forensics"
            "blueteam"
            "redteam"
          ];
        in
        {
          kali-slim = mkImage {
            name = "secforge-slim";
            presetPaths = combine [ "essential" ];
          };
          kali-network = mkImage {
            name = "secforge-network";
            presetPaths = combine [
              "essential"
              "network"
            ];
          };
          kali-web = mkImage {
            name = "secforge-web";
            presetPaths = combine [
              "essential"
              "web"
            ];
          };
          kali-password = mkImage {
            name = "secforge-password";
            presetPaths = combine [
              "essential"
              "password"
            ];
          };
          kali-recon = mkImage {
            name = "secforge-recon";
            presetPaths = combine [
              "essential"
              "recon"
            ];
          };
          kali-forensics = mkImage {
            name = "secforge-forensics";
            presetPaths = combine [
              "essential"
              "forensics"
            ];
          };
          kali-blueteam = mkImage {
            name = "secforge-blueteam";
            presetPaths = combine [
              "essential"
              "blueteam"
            ];
          };
          kali-redteam = mkImage {
            name = "secforge-redteam";
            presetPaths = combine [
              "essential"
              "redteam"
            ];
          };
          kali-full = mkImage {
            name = "secforge-full";
            presetPaths = combine allCategories;
          };
        }
      );

      nixosModules.default = import ./module;

      checks = nixpkgs.lib.genAttrs imageSystems (
        system:
        let
          pkgs = mkPkgs system;
        in
        {
          lint-statix = pkgs.runCommand "statix-check" { nativeBuildInputs = [ pkgs.statix ]; src = self; }
            ''
              statix check "$src" | tee "$out"
            '';
          lint-deadnix = pkgs.runCommand "deadnix-check" { nativeBuildInputs = [ pkgs.deadnix ]; src = self; }
            ''
              cd "$src"
              deadnix --fail $(find . -name '*.nix' -not -path './.git/*') | tee "$out"
            '';
          lint-fmt = pkgs.runCommand "nixfmt-check" { nativeBuildInputs = [ pkgs.nixfmt-rfc-style ]; src = self; }
            ''
              cd "$src"
              nixfmt --check $(find . -name '*.nix' -not -path './.git/*') | tee "$out"
            '';
        }
      );
    };
}
