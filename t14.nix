{ ownPkgs, dotpkgs, claude-desktop }: { config, lib, pkgs, ... }:

let
  dotpkgsDir = "/home/gsr/terminalenv/dotpkgs";
  # Electron refuses to start in this environment: the SUID sandbox helper in
  # the Nix store is not set up with the 4755 mode Electron requires, and the
  # namespace sandbox cannot be used here. Disable it.
  opencode-desktop = pkgs.opencode-desktop.override { commandLineArgs = "--no-sandbox"; };
in {
  dotfiles.packages = lib.mapAttrs (n: _: "${dotpkgsDir}/${n}") dotpkgs;

  home = {
    username = "gsr";
    homeDirectory = "/home/gsr";
    stateVersion = "24.11";
    packages = [
        ownPkgs.starship
        ownPkgs.repos
        opencode-desktop
        ownPkgs."dtu-learn"
        claude-desktop.packages.${pkgs.stdenv.hostPlatform.system}.default
        pkgs.claude-code
        pkgs.opencode
        pkgs.nodejs-slim
        pkgs.nodejs-slim.npm
    ];
  };

  programs.gh.enable = true;
  programs.sagemath.enable = true;
}
