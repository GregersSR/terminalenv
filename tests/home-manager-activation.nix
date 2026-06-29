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
  dotpkgs = flake.outputs.dotpkgs;
  isStore = mode == "store";
  packages = if isStore
    then dotpkgs
    else lib.mapAttrs (n: _: "${repoRoot}/dotpkgs/${n}") dotpkgs;
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

      dotfiles.packages = lib.mkForce packages;

      home.packages = [ ownpkgs.repos ];
    })
  ];
}).activationPackage
