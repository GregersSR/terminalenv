ownPkgs: { config, pkgs, ... }:

{
  home = {
    username = "gsr";
    homeDirectory = "/home/gsr";
    stateVersion = "24.11";
    packages = [
        ownPkgs.starship
        ownPkgs.pythonPackages.zotero-mcp-server
        ownPkgs.repos
    ];
  };

  programs.gh.enable = true;
  programs.sagemath.enable = true;
}
