{ config, lib, pkgs, ... }:

let
  cfg = config.dotfiles.links;
  packageRoot = name: ./. + "/${name}";
  repoRootArg = lib.escapeShellArg cfg.repoRoot;

  storePackageFiles =
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
  }) storePackageFiles);

  unstowCommands = lib.concatMapStringsSep "\n" (name:
    ''${pkgs.stow}/bin/stow --dir ${repoRootArg} --target "$HOME" --delete ${lib.escapeShellArg name}''
  ) cfg.storePackages;

  outOfStorePackageCheck = lib.concatMapStringsSep "\n" (name: ''
    if [ ! -d ${lib.escapeShellArg "${cfg.repoRoot}/${name}"} ]; then
      errorEcho "Dotfiles package directory not found: ${cfg.repoRoot}/${name}"
      exit 1
    fi
  '') cfg.outOfStorePackages;

  restowCommands = lib.concatMapStringsSep "\n" (name:
    ''${pkgs.stow}/bin/stow --dir ${repoRootArg} --target "$HOME" --restow ${lib.escapeShellArg name}''
  ) cfg.outOfStorePackages;
in {
  options.dotfiles.links = {
    enable = lib.mkEnableOption "dotfiles deployment";

    repoRoot = lib.mkOption {
      type = lib.types.str;
      default = "${config.home.homeDirectory}/terminalenv";
      description = ''
        Path to the local checkout, used for out-of-store packages.
      '';
    };

    storePackages = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "home" "repos" "opencode" ];
      description = ''
        Stow packages deployed via home.file from the Nix store.
      '';
    };

    outOfStorePackages = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = ''
        Stow packages deployed via stow from the local checkout at repoRoot.
      '';
    };
  };

  config = lib.mkMerge [
    {
      dotfiles.links.enable = lib.mkDefault true;
    }
    (lib.mkIf (cfg.enable && cfg.storePackages != [ ]) {
      home.file = storeManagedFiles;

      home.activation.dotfilesUnstow = lib.hm.dag.entryBefore [ "checkLinkTargets" ] ''
        if [ -d ${repoRootArg} ]; then
          ${unstowCommands}
        fi
      '';
    })
    (lib.mkIf (cfg.enable && cfg.outOfStorePackages != [ ]) {
      home.activation.dotfilesRestow = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
        if [ ! -d ${repoRootArg} ]; then
          errorEcho "Out-of-store dotfiles mode requires a local checkout at ${cfg.repoRoot}."
          exit 1
        fi

        ${outOfStorePackageCheck}

        ${restowCommands}
      '';
    })
  ];
}
