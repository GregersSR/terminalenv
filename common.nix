{ config, pkgs, ... }:

{
  imports = [ ./modules/symlinked-home-files.nix ];

  nix = {
    package = pkgs.nix;
    settings.experimental-features = [ "nix-command" "flakes" ];
  };

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;

  # Provide man pages for installed programs, but use system man.
  home.extraOutputsToInstall = [ "man" ];
  programs.man.enable = false;

  home.packages = [
    pkgs.cargo
    pkgs.gef
    pkgs.git-annex
    pkgs.jqp
    pkgs.git-filter-repo
    pkgs.pixi
  ];

  dotfiles.links = {
    enable = true;
    mode = "out-of-store";
    repoRoot = "${config.home.homeDirectory}/terminalenv";
  };

  home.shell = {
    enableBashIntegration = true;
    enableZshIntegration = true;
  };

  home.sessionVariables.TERMENV = "${config.xdg.configHome}/terminalenv";


  programs = {
    neovim = {
      enable = true;
      vimAlias = true;
      defaultEditor = true;
      extraConfig = ''
      source $TERMENV/home/nvim/settings.vim
      '';	
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

    git = {
      enable = true;
      settings = {
        core = {
          autocrlf = "input";
          editor = "nvim";
        };
        pull.ff = "only";
        init.defaultBranch = "main";
        init.templateDir = "${config.xdg.configHome}/git/template";
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
      git.enable = true;
    };
  };
}
