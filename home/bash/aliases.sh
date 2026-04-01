# Navigation
alias -- '-'='cd -'
alias '...'='../..'
alias '....'='../../..'
alias '.....'='../../../..'
alias '......'='../../../../..'
alias 1='cd -1'
alias 2='cd -2'
alias 3='cd -3'
alias 4='cd -4'
alias 5='cd -5'
alias 6='cd -6'
alias 7='cd -7'
alias 8='cd -8'
alias 9='cd -9'
alias _='sudo '

# grep
alias grep='grep --color=auto --exclude-dir={.git,.idea}'
alias zgrep='zgrep --color=auto'

# TODO: define git_develop_branch, git_main_branch, git_current_branch

# Git
alias g=git
alias ga='git add'
alias gaa='git add --all'
alias gc='git commit --verbose'
alias 'gc!'='git commit --verbose --amend'
alias gcB='git checkout -B'
alias gca='git commit --verbose --all'
alias gcd='git checkout $(git_develop_branch)'
alias gcm='git checkout $(git_main_branch)'
alias gd='git diff'
alias gds='git diff --staged'
alias gf='git fetch'
alias gl='git pull'
alias glg='git log --stat'
alias glgg='git log --graph'
alias glgga='git log --graph --decorate --all'
alias glog='git log --oneline --decorate --graph'
alias gm='git merge'
alias gp='git push'
alias gpf='git push --force-with-lease --force-if-includes'
alias gpsup='git push --set-upstream origin $(git_current_branch)'
alias gst='git status'
alias gsta='git stash push'
alias gstd='git stash drop'
alias gstl='git stash list'
alias gstp='git stash pop'
alias gsw='git switch'
alias gswc='git switch --create'
alias gswd='git switch $(git_develop_branch)'
alias gswm='git switch $(git_main_branch)'

__git_complete ga _git_add
__git_complete gaa _git_add
__git_complete gc _git_commit
__git_complete 'gc!' _git_commit
__git_complete gcB _git_checkout
__git_complete gca _git_commit
__git_complete gcd _git_checkout
__git_complete gcm _git_checkout
__git_complete gd _git_diff
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

# ls
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

if cmd_exists home-manager; then
	alias hms='home-manager switch'
fi

# Other
alias md='mkdir -p'

alias sum='paste -sd+ | bc'
alias alert='notify-send --urgency=low -i "$([ $? = 0 ] && echo terminal || echo error)" "$(history|tail -n1|sed -e '\''s/^\s*[0-9]\+\s*//;s/[;&|]\s*alert$//'\'')"'
