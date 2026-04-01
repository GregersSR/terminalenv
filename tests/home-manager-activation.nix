{ mode ? "out-of-store"
, homeDirectory
}:

let
  flake = builtins.getFlake ("path:" + builtins.toString ../.);
  pkgs = flake.inputs.nixpkgs.legacyPackages.${builtins.currentSystem};
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
      home.username = "tester";
      home.homeDirectory = homeDirectory;
      home.stateVersion = "24.11";

      dotfiles.links.mode = lib.mkForce mode;
      dotfiles.links.repoRoot = lib.mkForce "/repo";
    }
  ];
}).activationPackage
