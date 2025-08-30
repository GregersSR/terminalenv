export EDITOR=nvim
# don't export CDPATH to child processes; it should only be in effect for the current shell session
CDPATH=..

if cmd_exists bat; then
    export MANPAGER = "sh -c 'col -bx | bat -l man -p'";
    export MANROFFOPT = "-c";
fi
    
