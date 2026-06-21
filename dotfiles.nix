{ config, lib, pkgs, ... }:

let
  cfg = config.dotfiles.links;
  packageRoot = name: ./. + "/${name}";
  repoRootArg = lib.escapeShellArg cfg.repoRoot;

  storePackagesFiles =
    let
      selected = map (name: {
        inherit name;
        root = packageRoot name;
      }) cfg.storePackages;
    in
      lib.concatMap (pkg:
        map (path: {
          relativePath = lib.removePrefix "${toString pkg.root}/" (toString path);
          inherit path;
        }) (lib.filesystem.listFilesRecursive pkg.root)
      ) selected;

  storeManagedFiles = lib.listToAttrs (map (file: {
    name = file.relativePath;
    value = { source = file.path; };
  }) storePackagesFiles);

  unstowAll = lib.concatMapStringsSep "\n" (name: ''
    if [ -d ${repoRootArg}/${lib.escapeShellArg name} ]; then
      ${pkgs.stow}/bin/stow --dir ${repoRootArg} --target "$HOME" --delete ${lib.escapeShellArg name} 2>/dev/null || true
    fi
  '') cfg.packages;

  outOfStoreChecks = lib.concatMapStringsSep "\n" (name: ''
    if [ ! -d ${lib.escapeShellArg "${cfg.repoRoot}/${name}"} ]; then
      errorEcho "Out-of-store dotfiles package not found: ${cfg.repoRoot}/${name}"
      exit 1
    fi
  '') cfg.outOfStorePackages;

  restowOutOfStore = lib.concatMapStringsSep "\n" (name:
    ''${pkgs.stow}/bin/stow --dir ${repoRootArg} --target "$HOME" --restow ${lib.escapeShellArg name}''
  ) cfg.outOfStorePackages;
in {
  options.dotfiles.links = {
    enable = lib.mkEnableOption "dotfiles deployment";

    repoRoot = lib.mkOption {
      type = lib.types.str;
      default = "${config.home.homeDirectory}/terminalenv";
      description = ''
        Path to the local checkout. Used for out-of-store packages and
        for unstowing stale symlinks before deploying store packages.
      '';
    };

    packages = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "home" "repos" "opencode" ];
      description = ''
        All known stow packages in this repository. Before deploying,
        any symlink managed by stow for these packages is removed,
        guaranteeing no leftovers when packages move between modes.
        Must be a superset of both storePackages and outOfStorePackages.
      '';
    };

    storePackages = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "home" "repos" "opencode" ];
      description = ''
        Subset of packages deployed via home.file from the Nix store
        (absolute symlinks, managed by Home Manager).
      '';
    };

    outOfStorePackages = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = ''
        Subset of packages deployed via stow from the local repo checkout
        (relative symlinks, managed by stow).
      '';
    };
  };

  config = lib.mkMerge [
    {
      dotfiles.links.enable = lib.mkDefault true;
    }

    # Validate that storePackages and outOfStorePackages are subsets of packages
    {
      assertions = [
        {
          assertion = lib.all (p: lib.elem p cfg.packages) cfg.storePackages;
          message = "dotfiles.links: every entry in storePackages must also be in packages";
        }
        {
          assertion = lib.all (p: lib.elem p cfg.packages) cfg.outOfStorePackages;
          message = "dotfiles.links: every entry in outOfStorePackages must also be in packages";
        }
      ];
    }

    # Deploy store packages via home.file (absolute Nix store symlinks)
    (lib.mkIf (cfg.enable && cfg.storePackages != [ ]) {
      home.file = storeManagedFiles;
    })

    # Before HM creates links: drop all stow-managed symlinks for every known
    # package. This cleans up prior out-of-store deployments, including
    # packages that have been removed entirely from both lists.
    (lib.mkIf (cfg.enable && cfg.packages != [ ]) {
      home.activation.dotfilesUnstow = lib.hm.dag.entryBefore [ "checkLinkTargets" ] ''
        ${unstowAll}
      '';
    })

    # After HM links: restow out-of-store packages from the local checkout
    (lib.mkIf (cfg.enable && cfg.outOfStorePackages != [ ]) {
      home.activation.dotfilesRestow = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
        if [ ! -d ${repoRootArg} ]; then
          errorEcho "Out-of-store dotfiles mode requires a local checkout at ${cfg.repoRoot}."
          exit 1
        fi

        ${outOfStoreChecks}

        ${restowOutOfStore}
      '';
    })
  ];
}
