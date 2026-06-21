{ config, lib, pkgs, ... }:

let
  cfg = config.dotfiles.links;

  # Single source of truth for the dotpkgs directory
  dotpkgsDir = ./dotpkgs;
  dotpkgsDirArg = "${lib.escapeShellArg cfg.repoRoot}/dotpkgs";

  # Known packages — everything in dotpkgs/
  dotpkgsEntries = builtins.readDir dotpkgsDir;
  allPackages = lib.attrNames (lib.filterAttrs (n: v: v == "directory") dotpkgsEntries);

  # Files from store packages, keyed by $HOME-relative path
  storePackagesFiles = lib.concatMap (name:
    let root = dotpkgsDir + "/${name}";
    in map (path: {
      relativePath = lib.removePrefix "${toString root}/" (toString path);
      inherit path;
    }) (lib.filesystem.listFilesRecursive root)
  ) cfg.storePackages;

  storeManagedFiles = lib.listToAttrs (map (file: {
    name = file.relativePath;
    value = { source = file.path; };
  }) storePackagesFiles);

  # bash activation commands
  unstowAll = lib.concatMapStringsSep "\n" (name: ''
    if [ -d ${dotpkgsDirArg}/${lib.escapeShellArg name} ]; then
      ${pkgs.stow}/bin/stow --dir ${dotpkgsDirArg} --target "$HOME" --delete ${lib.escapeShellArg name} 2>/dev/null || true
    fi
  '') allPackages;

  outOfStoreChecks = lib.concatMapStringsSep "\n" (name: ''
    if [ ! -d ${dotpkgsDirArg}/${lib.escapeShellArg name} ]; then
      errorEcho "Out-of-store dotfiles package not found: ${dotpkgsDirArg}/${name}"
      exit 1
    fi
  '') cfg.outOfStorePackages;

  restowOutOfStore = lib.concatMapStringsSep "\n" (name:
    ''${pkgs.stow}/bin/stow --dir ${dotpkgsDirArg} --target "$HOME" --restow ${lib.escapeShellArg name}''
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

    storePackages = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = allPackages;
      description = ''
        Subset of packages deployed via home.file from the Nix store
        (absolute symlinks, managed by Home Manager). Defaults to all
        packages found in dotpkgs/.
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

    # Validate that every listed package exists as a dotpkgs/ subdirectory
    {
      assertions = [
        {
          assertion = lib.all (p: lib.elem p allPackages) cfg.storePackages;
          message = "dotfiles.links: every entry in storePackages must be a directory under dotpkgs/";
        }
        {
          assertion = lib.all (p: lib.elem p allPackages) cfg.outOfStorePackages;
          message = "dotfiles.links: every entry in outOfStorePackages must be a directory under dotpkgs/";
        }
      ];
    }

    # Deploy store packages via home.file (absolute Nix store symlinks)
    (lib.mkIf (cfg.enable && cfg.storePackages != [ ]) {
      home.file = storeManagedFiles;
    })

    # Before HM creates links: drop all stow-managed symlinks for every known
    # package. This cleans up prior out-of-store deployments, including
    # packages that have been removed from dotpkgs/ entirely.
    (lib.mkIf (cfg.enable && allPackages != [ ]) {
      home.activation.dotfilesUnstow = lib.hm.dag.entryBefore [ "checkLinkTargets" ] ''
        ${unstowAll}
      '';
    })

    # After HM links: restow out-of-store packages from the local checkout
    (lib.mkIf (cfg.enable && cfg.outOfStorePackages != [ ]) {
      home.activation.dotfilesRestow = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
        if [ ! -d ${lib.escapeShellArg cfg.repoRoot} ]; then
          errorEcho "Out-of-store dotfiles mode requires a local checkout at ${cfg.repoRoot}."
          exit 1
        fi

        ${outOfStoreChecks}

        ${restowOutOfStore}
      '';
    })
  ];
}
