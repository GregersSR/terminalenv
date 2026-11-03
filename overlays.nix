# Temporary fixes for broken packages in the pinned nixpkgs.
final: prev: {
  # nixpkgs ships a stale node_modules hash for opencode 2.2.5.
  # https://github.com/NixOS/nixpkgs/issues/582673 — drop once
  # https://github.com/NixOS/nixpkgs/pull/582675 reaches nixpkgs-unstable.
  # opencode-desktop inherits node_modules from opencode, so this fixes both.
  opencode = prev.opencode.overrideAttrs (old: {
    node_modules = old.node_modules.overrideAttrs {
      outputHash = "sha256-prx9dX7kUvs/E3zopkaPk5LXh3xJAy5sZeum/W8L7cA=";
    };
  });
}
