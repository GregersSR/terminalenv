{ mode ? "out-of-store"
, homeDirectory
, repoRoot
, flakeRoot ? builtins.toString ../.
}:

let
  flake = builtins.getFlake ("path:" + flakeRoot);
  pkgs = flake.inputs.nixpkgs.legacyPackages.${builtins.currentSystem};
  ownpkgs = flake.outputs.packages.${builtins.currentSystem};
  lib = pkgs.lib;
in
(flake.inputs.home-manager.lib.homeManagerConfiguration {
  inherit pkgs;
  extraSpecialArgs = {
    nixpkgsFlake = flake.inputs.nixpkgs;
  };
  modules = [
    flake.outputs.modules.dotfiles
    flake.outputs.modules.common
    ({ lib, ... }: {
      home.username = "tester";
      home.homeDirectory = homeDirectory;
      home.stateVersion = "24.11";

      dotfiles.links.mode = lib.mkForce mode;
      dotfiles.links.repoRoot = lib.mkForce repoRoot;

      home.packages = [ ownpkgs.repos ];
    })
  ];
}).activationPackage
