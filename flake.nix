{
  description = "Code behind search.nixos.org";

  inputs = { nixpkgs = { url = "nixpkgs/nixos-unstable"; }; };

  outputs = { self, nixpkgs }:
    let
      systems = [ "x86_64-linux" "i686-linux" "x86_64-darwin" "aarch64-linux" ];
      forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f system);
      mkPackage = path: system:
        let
          pkgs = import nixpkgs {
            inherit system;
            overlays = [ ];
          };
        in import path { inherit pkgs; };
      packages = system: {
        flake_info = mkPackage ./flake-info system;
        flake_repos = mkPackage ./flake-repos system;
        frontend = mkPackage ./. system;
      };

      devShell = system:
        nixpkgs.legacyPackages.${system}.mkShell {
          inputsFrom = builtins.attrValues (packages system);
        };
    in {
      defaultPackage = forAllSystems (mkPackage ./.);
      packages = forAllSystems packages;
      devShell = forAllSystems devShell;
    };
}
