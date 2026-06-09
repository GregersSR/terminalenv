# Bash-specific navigation alias (shared file can't unify `-` alias syntax)
alias -- '-'='cd -'

# Source shared aliases
shared_aliases="$(cd "$(dirname "$(realpath "${BASH_SOURCE[0]}")")/../shell" >/dev/null 2>&1 && pwd)/aliases"
if [ -f "$shared_aliases" ]; then
  source "$shared_aliases"
else
  echo "Warning: shared aliases not found at $shared_aliases" >&2
fi
unset shared_aliases

# Bash-specific aliases
alias _='sudo '
alias grep='grep --color=auto --exclude-dir={.git,.idea}'
alias zgrep='zgrep --color=auto'

if declare -F __git_complete >/dev/null 2>&1; then
  __git_complete ga _git_add
  __git_complete gaa _git_add
  __git_complete gc _git_commit
  __git_complete 'gc!' _git_commit
  __git_complete gcB _git_checkout
  __git_complete gca _git_commit
  __git_complete gcd _git_checkout
  __git_complete gcm _git_checkout
  __git_complete gd _git_diff
  __git_complete gdp _git_diff
  __git_complete gds _git_diff
  __git_complete gf _git_fetch
  __git_complete gl _git_pull
  __git_complete glg _git_log
  __git_complete glgg _git_log
  __git_complete glgga _git_log
  __git_complete glog _git_log
  __git_complete gm _git_merge
  __git_complete gp _git_push
  __git_complete gpf _git_push
  __git_complete gpsup _git_push
  __git_complete gst _git_status
  __git_complete gsta _git_stash
  __git_complete gstd _git_stash
  __git_complete gstl _git_stash
  __git_complete gstp _git_stash
  __git_complete gsw _git_switch
  __git_complete gswc _git_switch
  __git_complete gswd _git_switch
  __git_complete gswm _git_switch
fi

# ls with fallback
if cmd_exists eza; then
  alias ls='eza '
  alias l='eza -lgh '
  alias la='eza -a '
  alias ll='eza -lgAh '
  alias lt='eza --tree '
else
  alias ls='ls --color=auto '
  alias l='ls -lh '
  alias la='ls -a '
  alias ll='ls -lah '
  alias lt='tree '
fi

alias alert='notify-send --urgency=low -i "$([ $? = 0 ] && echo terminal || echo error)" "$(history|tail -n1|sed -e '\''s/^\s*[0-9]\+\s*//;s/[;&|]\s*alert$//'\'')"'
