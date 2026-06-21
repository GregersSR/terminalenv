# Source HM-generated configuration if Home Manager is active
if test -f "$__fish_config_dir/hm-generated.fish"
    source "$__fish_config_dir/hm-generated.fish"
end

# Source shared aliases
set -l __shared_aliases "$__fish_config_dir/../shell/aliases"
if test -f "$__shared_aliases"
    source "$__shared_aliases"
end

# Environment
set -gx EDITOR nvim
set -g CDPATH . ..

if type -q bat
    set -gx MANPAGER "sh -c 'col -bx | bat -l man -p'"
    set -gx MANROFFOPT -c
end

if test -d "$HOME/.opencode/bin"
    fish_add_path --append "$HOME/.opencode/bin"
end

# Prompt
if type -q starship
    starship init fish | source
end

# Direnv
if type -q direnv
    direnv hook fish | source
end
