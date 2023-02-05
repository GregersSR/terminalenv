export VISUAL=nvim
export EDITOR="${VISUAL}"
export PATH="$PATH:$(go env GOPATH)/bin"
[ -f "/home/gsr/.ghcup/env" ] && source "/home/gsr/.ghcup/env" # ghcup-env
