{
  description = "T3 Code desktop app, built from an arbitrary upstream branch";

  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

  outputs =
    { self, nixpkgs }:
    let
      systems = [ "x86_64-linux" ];
      forAllSystems = nixpkgs.lib.genAttrs systems;
    in
    {
      packages = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          t3code = pkgs.callPackage ./package.nix { };
          default = self.packages.${system}.t3code;
        }
      );

      # The point of the flake. A consumer pinned to a different upstream branch
      # overrides here rather than forking:
      #
      #   t3code.packages.${system}.t3code.override {
      #     branch  = "t3code/codex-turn-mapping";
      #     version = "0.0.33";
      #     url     = "https://github.com/cjavad/nixpille-t3code/releases/download/...";
      #     hash    = "sha256-...";
      #   }
      #
      # or through the NixOS module's options, which do the same thing.
      nixosModules.default = import ./module.nix self;

      overlays.default = final: _: {
        t3code = self.packages.${final.stdenv.hostPlatform.system}.default;
      };

      # `nix run` for a throwaway launch without installing.
      apps = forAllSystems (system: {
        default = {
          type = "app";
          program = "${self.packages.${system}.t3code}/bin/t3code";
        };
      });
    };
}
