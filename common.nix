{ config, lib, pkgs, ownPkgs, ... }:

{
  nix = {
    package = pkgs.nix;
    settings.experimental-features = [ "nix-command" "flakes" ];
  };

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;

  # Provide man pages for installed programs, but use system man.
  home.extraOutputsToInstall = [ "man" ];
  programs.man.enable = false;

  home.packages = with pkgs; [
    cargo
    gef
    git
    git-annex
    jqp
    git-filter-repo
    pixi
    pandoc
    fd
    ripgrep
    ownPkgs.repos
    stow
  ];

  home.shell = {
    enableBashIntegration = true;
    enableZshIntegration = true;
  };


  programs = {
    neovim = {
      enable = true;
      vimAlias = true;
      defaultEditor = true;
      plugins = with pkgs.vimPlugins; [
        nvim-treesitter.withAllGrammars
        plenary-nvim
        diffview-nvim
        telescope-nvim
        neogit
      ];
    };

    bat.enable = true;
    eza = {
      enable = true;
      enableBashIntegration = false;
      enableZshIntegration = true;
    };

    zsh = {
      enable = true;
      oh-my-zsh = {
        enable = true;
        plugins = ["git"];
        theme = "sunrise";
      };
    };

    ssh = {
      enable = true;
      enableDefaultConfig = false;
      includes = [ "config.d/*" ];
      matchBlocks."*".hashKnownHosts = false;
    };

    direnv = {
      enable = true;
      nix-direnv.enable = true;
    };

    difftastic = {
      enable = true;
    };
  };

  xdg.configFile."nvim/init.lua".enable = lib.mkForce false;
  xdg.configFile."nvim/hm-generated.lua" = lib.mkIf config.programs.neovim.enable {
    text = config.programs.neovim.initLua;
  };
}
