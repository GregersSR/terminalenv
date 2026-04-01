{ mode ? "out-of-store"
, homeDirectory
, username ? "tester"
, system ? builtins.currentSystem
, repoRoot ? builtins.toString ../.
}:

let
  flake = builtins.getFlake ("path:" + builtins.toString ../.);
  pkgs = flake.inputs.nixpkgs.legacyPackages.${system};
  lib = pkgs.lib;
  localpkgs = import ../packages pkgs;
in
(flake.inputs.home-manager.lib.homeManagerConfiguration {
  inherit pkgs;
  extraSpecialArgs = {
    inherit localpkgs;
  };
  modules = [
    ../common.nix
    {
      home.username = username;
      home.homeDirectory = homeDirectory;
      home.stateVersion = "24.11";

      dotfiles.links.mode = lib.mkForce mode;
      dotfiles.links.repoRoot = lib.mkForce repoRoot;
    }
  ];
}).activationPackage
