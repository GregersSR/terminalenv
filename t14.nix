{ ownPkgs, dotpkgs }: { config, lib, pkgs, ... }:

let
  dotpkgsDir = "/home/gsr/terminalenv/dotpkgs";
in {
  dotfiles.packages = lib.mapAttrs (n: _: "${dotpkgsDir}/${n}") dotpkgs;

  home = {
    username = "gsr";
    homeDirectory = "/home/gsr";
    stateVersion = "24.11";
    packages = [
        ownPkgs.starship
        ownPkgs.pythonPackages.zotero-mcp-server
        ownPkgs.repos
        pkgs.nodejs-slim
        pkgs.nodejs-slim.npm
    ];
  };

  programs.gh.enable = true;
  programs.sagemath.enable = true;
}
