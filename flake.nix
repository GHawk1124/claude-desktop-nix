{
  description = "Claude Desktop for NixOS, packaged from Anthropic's official Linux binary";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    { self
    , nixpkgs
    , flake-utils
    , ...
    }:
    flake-utils.lib.eachSystem [ "x86_64-linux" "aarch64-linux" ]
      (
        system:
        let
          pkgs = import nixpkgs {
            inherit system;
            config.allowUnfree = true;
          };
        in
        {
          packages.default = pkgs.callPackage ./package.nix { };
          packages.claude-desktop = self.packages.${system}.default;

          apps.default = {
            type = "app";
            program = "${self.packages.${system}.default}/bin/claude-desktop";
          };
          apps.claude-desktop = self.apps.${system}.default;

          devShells.default = pkgs.mkShell {
            packages = [
              pkgs.nix-prefetch
              pkgs.nixpkgs-fmt
            ];
          };

          formatter = pkgs.nixpkgs-fmt;
        }
      )
    // {
      overlays.default = final: _prev: {
        claude-desktop = final.callPackage ./package.nix { };
      };
    };
}
