ownPkgs: { config, lib, pkgs, ... }:

{
  dotfiles.links = {
    storePackages = [ ];
    outOfStorePackages = [ "home" "repos" "aitools" ];
  };
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
