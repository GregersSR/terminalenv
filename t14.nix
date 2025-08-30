{ config, pkgs, ... }:

{
  home = {
    username = "gsr";
    homeDirectory = "/home/gsr";
    stateVersion = "24.11";
  };

  programs.git = {
    userName = "Gregers Rørdam";
    userEmail = "gregers@rordam.dk";
  };

  programs.gh.enable = true;
  programs.sagemath.enable = true;
}
