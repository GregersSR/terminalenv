{ config, lib, pkgs, ... }:

let
  fishConfig = builtins.readFile ./fish/config.fish;
  fishFunction = name: builtins.readFile (./fish/functions + "/${name}.fish");
in {
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
      interactiveShellInit = fishConfig;
      functions = {
        git_develop_branch = fishFunction "git_develop_branch";
        git_main_branch = fishFunction "git_main_branch";
        git_current_branch = fishFunction "git_current_branch";
      };
      shellAliases = {
        "-" = "cd -";
        "..." = "../..";
        "...." = "../../..";
        "....." = "../../../..";
        "......" = "../../../../..";
        "1" = "cd -1";
        "2" = "cd -2";
        "3" = "cd -3";
        "4" = "cd -4";
        "5" = "cd -5";
        "6" = "cd -6";
        "7" = "cd -7";
        "8" = "cd -8";
        "9" = "cd -9";

        grep = "grep --color=auto --exclude-dir={.git,.idea}";
        zgrep = "zgrep --color=auto";

        g = "git";
        ga = "git add";
        gaa = "git add --all";
        gc = "git commit --verbose";
        "gc!" = "git commit --verbose --amend";
        gcB = "git checkout -B";
        gca = "git commit --verbose --all";
        gcd = "git checkout (git_develop_branch)";
        gcm = "git checkout (git_main_branch)";
        gd = "git diff";
        gdp = "git diff --no-ext-diff";
        gds = "git diff --staged";
        gf = "git fetch";
        gl = "git pull";
        glg = "git log --stat";
        glgg = "git log --graph";
        glgga = "git log --graph --decorate --all";
        glog = "git log --oneline --decorate --graph";
        gm = "git merge";
        gp = "git push";
        gpf = "git push --force-with-lease --force-if-includes";
        gpsup = "git push --set-upstream origin (git_current_branch)";
        gst = "git status";
        gsta = "git stash push";
        gstd = "git stash drop";
        gstl = "git stash list";
        gstp = "git stash pop";
        gsw = "git switch";
        gswc = "git switch --create";
        gswd = "git switch (git_develop_branch)";
        gswm = "git switch (git_main_branch)";

        ls = "eza";
        l = "eza -lgh";
        la = "eza -a";
        ll = "eza -lgAh";
        lt = "eza --tree";

        hms = "home-manager switch --flake ~/terminalenv#gsr";
        md = "mkdir -p";
        sum = "paste -sd+ | bc";
      };
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

  xdg.configFile."nvim/init.lua".enable = lib.mkForce false;
  xdg.configFile."nvim/hm-generated.lua" = lib.mkIf config.programs.neovim.enable {
    text = config.programs.neovim.initLua;
  };
}
