{ config, lib, ... }:

let
  cfg = config.dotfiles.links;
  manifestFile = ../symlinks.txt;
  repoSourceRoot = ../.;
  runtimeRootPath = "${config.home.homeDirectory}/terminalenv";

  rawEntries = lib.filter (line:
    line != "" && !lib.hasPrefix "#" line
  ) (lib.splitString "\n" (builtins.readFile manifestFile));

  parseEntry = line:
    let
      parts = lib.splitString "|" line;
    in
    if builtins.length parts != 3 then
      throw "Invalid symlink entry '${line}' in ${toString manifestFile}"
    else {
      root = builtins.elemAt parts 0;
      source = builtins.elemAt parts 1;
      target = builtins.elemAt parts 2;
    };

  entries = map parseEntry rawEntries;

  sourceFor = entry:
    if cfg.mode == "out-of-store" then
      config.lib.file.mkOutOfStoreSymlink "${cfg.repoRoot}/${entry.source}"
    else
      repoSourceRoot + "/${entry.source}";

  runtimeRootSource =
    if cfg.mode == "out-of-store" then
      config.lib.file.mkOutOfStoreSymlink cfg.repoRoot
    else
      repoSourceRoot;

  runtimeRootEntry = lib.optionalAttrs (!(cfg.mode == "out-of-store" && cfg.repoRoot == runtimeRootPath)) {
    "terminalenv" = {
      source = runtimeRootSource;
    };
  };

  entryValue = entry: {
    source = sourceFor entry;
  };

  filterByRoot = root: builtins.filter (entry: entry.root == root) entries;

  toAttrs = root:
    lib.listToAttrs (map (entry: {
      name = entry.target;
      value = entryValue entry;
    }) (filterByRoot root));

  validRoots = [ "home" "xdg-config" ];
  invalidRoots = builtins.filter (root: !(builtins.elem root validRoots))
    (map (entry: entry.root) entries);
in
{
  options.dotfiles.links = {
    enable = lib.mkEnableOption "shared symlink manifest for native dotfiles";

    mode = lib.mkOption {
      type = lib.types.enum [ "store" "out-of-store" ];
      default = "store";
      description = ''
        Whether Home Manager should materialize files from the flake source in the
        Nix store or create out-of-store symlinks back to the checkout.
      '';
    };

    repoRoot = lib.mkOption {
      type = lib.types.str;
      default = "${config.home.homeDirectory}/terminalenv";
      example = "${config.home.homeDirectory}/src/dotfiles";
      description = ''
        Checkout path used when link mode is `out-of-store`. This should point at
        the repository root in the home directory.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = invalidRoots == [ ];
        message = "symlinks.txt contains an unsupported root; expected one of: ${lib.concatStringsSep ", " validRoots}";
      }
    ];

    home.file = (toAttrs "home") // runtimeRootEntry;
    xdg.configFile = toAttrs "xdg-config";
  };
}
