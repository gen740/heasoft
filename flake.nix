{
  description = "HEASoft and XMM SAS packages";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
  };

  outputs =
    inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } rec {
      systems = [
        "x86_64-linux"
        "aarch64-darwin"
        "x86_64-darwin"
      ];

      flake = {
        flakeModules = {
          heasoft = import ./src/heasoft.nix { };
          xmmsas = import ./src/xmmsas.nix { };
          caldb = import ./src/caldb.nix { };
        };
        mkFlakeModules = {
          heasoft = import ./src/heasoft.nix;
          xmmsas = import ./src/xmmsas.nix;
          caldb = import ./src/caldb.nix;
        };
      };

      imports = [
        flake.flakeModules.heasoft
        flake.flakeModules.xmmsas
        flake.flakeModules.caldb
      ];
    };
}
