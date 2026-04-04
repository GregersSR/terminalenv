function cmd_exists {
    local cmd="$1"
    command -v "$cmd" >/dev/null
}

function zcat () {
    gzip -cd | cat "$@"
}

# Returns the path of the executing script (ie. the one that has called into this code top-level). This is a script that was either run as main or sourced.
function toplevel_script {
    # traverse the call stack until either "main" or "source" is encountered. This means we get the script that called this function.
    i=0
    while [[ "${FUNCNAME[i]}" != "main" && "${FUNCNAME[i]}" != "source" ]]; do
        i=$((i + 1))
    done
    echo "${BASH_SOURCE[i]}"
}

function main_script {
    echo "${BASH_SOURCE[-1]}"
}

# Returns the directory of the script given as first argument
function script_dir {
    # based on this thread: https://stackoverflow.com/questions/59895/how-do-i-get-the-directory-where-a-bash-script-is-located-from-within-the-script
    # since element 1 is the script that called this function, even if the call was made in a function that was sourced into another script and called
    local SOURCE_PATH="$1"
    local SYMLINK_DIR
    local SCRIPT_DIR
    # Resolve symlinks recursively
    while [ -L "$SOURCE_PATH" ]; do
        # Get symlink directory
        SYMLINK_DIR="$( cd -P "$( dirname "$SOURCE_PATH" )" >/dev/null 2>&1 && pwd )"
        # Resolve symlink target (relative or absolute)
        SOURCE_PATH="$(readlink "$SOURCE_PATH")"
        # Check if candidate path is relative or absolute
        if [[ $SOURCE_PATH != /* ]]; then
            # Candidate path is relative, resolve to full path
            SOURCE_PATH=$SYMLINK_DIR/$SOURCE_PATH
        fi
    done

    OLD_CDPATH="${CDPATH}"
    CDPATH=""
    # Get final script directory path from fully resolved source path
    SCRIPT_DIR="$(cd -P "$( dirname "$SOURCE_PATH" )" >/dev/null 2>&1 && pwd)"
    echo "$SCRIPT_DIR"
    CDPATH="${OLD_CDPATH}"
}

# Returns the directory of the script calling this function, even if the call was made in a function sourced into another script.
function this_script_dir {
    script_dir "${BASH_SOURCE[1]}"
}

function toplevel_script_dir {
    script_dir "$(toplevel_script)"
}

function main_script_dir {
    script_dir "$(main_script)"
}

# Next two functions adapted from the oh-my-zsh git plugin
function git_develop_branch() {
  command git rev-parse --git-dir &>/dev/null || return
  local branch
  for branch in dev devel develop development; do
    if command git show-ref -q --verify refs/heads/$branch; then
      echo $branch
      return 0
    fi
  done

  echo develop
  return 1
}

# Get the default branch name from common branch names or fallback to remote HEAD
function git_main_branch() {
  command git rev-parse --git-dir &>/dev/null || return
  
  local remote ref
  
  for ref in refs/{heads,remotes/{origin,upstream}}/{main,trunk,mainline,default,stable,master}; do
    if command git show-ref -q --verify $ref; then
      echo ${ref##*/}
      return 0
    fi
  done
  
  # Fallback: try to get the default branch from remote HEAD symbolic refs
  for remote in origin upstream; do
    ref=$(command git rev-parse --abbrev-ref $remote/HEAD 2>/dev/null)
    if [[ $ref == $remote/* ]]; then
      echo ${ref#"$remote/"}; return 0
    fi
  done

  # If no main branch was found, fall back to master but return error
  echo master
  return 1
}
