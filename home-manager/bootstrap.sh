# From a working Nix install, this script sets up Home-Manager.
# First, a symlink to flake.nix is created in ~/.config/home-manager
# Next, the

nix --extra-experimental-features nix-command --extra-experimental-features flakes run --refresh home-manager/master -- switch --flake ./home-manager/.#gsr --option 'extra-experimental-features' 'nix-command' --option 'extra-experimental-features' flakes
