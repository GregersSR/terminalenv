set -gx EDITOR nvim
set -g CDPATH . ..

if type -q bat
  set -gx MANPAGER "sh -c 'col -bx | bat -l man -p'"
  set -gx MANROFFOPT -c
end

if test -d "$HOME/.opencode/bin"
  fish_add_path --append "$HOME/.opencode/bin"
end

if type -q starship
  starship init fish | source
end

if type -q direnv
  direnv hook fish | source
end
