{ config, pkgs, ... }:

{
  home = {
    username = "gsr";
    homeDirectory = "/home/gsr";
    stateVersion = "23.11";
  };

  programs.git = {
    userName = "Gregers Rørdam";
    userEmail = "gregers@rordam.dk";
  };
}
