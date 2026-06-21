# If not running interactively, don't do anything
case $- in
    *i*) ;;
      *) return;;
esac

# don't put duplicate lines or lines starting with space in the history.
# See bash(1) for more options
HISTCONTROL=ignoreboth

# append to the history file, don't overwrite it
shopt -s histappend

# for setting history length see HISTSIZE and HISTFILESIZE in bash(1)
HISTSIZE=10000
HISTFILESIZE=20000

# check the window size after each command and, if necessary,
# update the values of LINES and COLUMNS.
shopt -s checkwinsize

# If set, the pattern "**" used in a pathname expansion context will
# match all files and zero or more directories and subdirectories.
shopt -s globstar

# make less more friendly for non-text input files, see lesspipe(1)
[ -x /usr/bin/lesspipe ] && eval "$(SHELL=/bin/sh lesspipe)"


# enable color support of ls and also add handy aliases
if [ -x /usr/bin/dircolors ]; then
    test -r ~/.dircolors && eval "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"
fi

# enable programmable completion features (you don't need to enable
# this, if it's already enabled in /etc/bash.bashrc and /etc/profile
# sources /etc/bash.bashrc).
if ! shopt -oq posix; then
  if [ -f /usr/share/bash-completion/bash_completion ]; then
    . /usr/share/bash-completion/bash_completion
  elif [ -f /etc/bash_completion ]; then
    . /etc/bash_completion
  fi
fi

BASH_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}/bash"

if [ ! -f "${BASH_CONFIG_HOME}/lib.sh" ]; then
  echo "Error: expected bash support files under '${BASH_CONFIG_HOME}'." >&2
  return 1
fi

if [ -f "${BASH_CONFIG_HOME}/completions/git" ]; then
  source "${BASH_CONFIG_HOME}/completions/git"
elif [ -f /usr/share/bash-completion/completions/git ]; then
  source /usr/share/bash-completion/completions/git
else
  echo "Warning: git completion not found" >&2
fi
export GIT_COMPLETION_CHECKOUT_NO_GUESS=1

source "${BASH_CONFIG_HOME}/lib.sh"
source "${BASH_CONFIG_HOME}/env.sh"
source "${BASH_CONFIG_HOME}/aliases.sh"
source "${BASH_CONFIG_HOME}/prompt.sh"
source "${BASH_CONFIG_HOME}/path.sh"

if command -v direnv >/dev/null 2>&1; then
  eval "$(direnv hook bash)"
fi

unset BASH_CONFIG_HOME
