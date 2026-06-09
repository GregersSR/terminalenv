{ config, lib, pkgs, ... }: {
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
    stow
  ];

  home.shell = {
    enableBashIntegration = true;
    enableFishIntegration = true;
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
      withRuby = false;
      withPython3 = false;
    };

    bat.enable = true;
    eza = {
      enable = true;
      enableBashIntegration = false;
      enableFishIntegration = true;
      enableZshIntegration = true;
    };

    fish = {
      enable = true;
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
      settings."*".HashKnownHosts = false;
    };

    direnv = {
      enable = true;
      nix-direnv.enable = true;
    };

    difftastic = {
      enable = true;
    };
  };

  xdg.configFile."fish/config.fish".enable = lib.mkForce false;
  xdg.configFile."fish/hm-generated.fish" = lib.mkIf config.programs.fish.enable {
    text = ''
      # Home Manager integration for fish — auto-generated.
      # User customizations belong in ~/.config/fish/config.fish.

      # Source HM session variables
      set -l __hm_sv "$HOME/.local/state/nix/profiles/home-manager/home-path/etc/fish/hm-session-vars.fish"
      if test -f "$__hm_sv"
        source "$__hm_sv"
      end
    '';
  };

  xdg.configFile."nvim/init.lua".enable = lib.mkForce false;
  xdg.configFile."nvim/hm-generated.lua" = lib.mkIf config.programs.neovim.enable {
    text = config.programs.neovim.initLua;
  };
}
