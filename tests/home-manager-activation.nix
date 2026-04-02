{ mode ? "out-of-store"
, homeDirectory
, repoRoot
, flakeRoot ? builtins.toString ../.
}:

let
  flake = builtins.getFlake ("path:" + flakeRoot);
  moduleRoot = builtins.path {
    path = builtins.toPath flakeRoot;
    name = "dotfiles-source";
  };
  pkgs = flake.inputs.nixpkgs.legacyPackages.${builtins.currentSystem};
  lib = pkgs.lib;
in
(flake.inputs.home-manager.lib.homeManagerConfiguration {
  inherit pkgs;
  modules = [
    (moduleRoot + "/dotfiles.nix")
    (moduleRoot + "/common.nix")
    ({ lib, ... }: {
      home.username = "tester";
      home.homeDirectory = homeDirectory;
      home.stateVersion = "24.11";

      dotfiles.links.mode = lib.mkForce mode;
      dotfiles.links.repoRoot = lib.mkForce repoRoot;
    })
  ];
}).activationPackage
