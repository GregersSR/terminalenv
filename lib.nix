{ lib, writeScript }:

let
  # Recursively render a nested attrset of commands into bash case blocks
  renderTree = level: tree:
    let
      pad = lib.concatStringsSep "" (lib.replicate level "  ");
      body = lib.concatStringsSep "\n" (lib.mapAttrsToList (key: val:
        if lib.isString val then
          ''
${pad}  ${key})
${pad}    shift ${toString level}
${pad}    ${val}
${pad}    ;;
''
        else if lib.isAttrs val then
          ''
${pad}  ${key})
${pad}    shift
${pad}    case "$1" in
${renderTree (level + 2) val}
${pad}      *)
${pad}        command "${cmd}" "$@"
${pad}        ;;
${pad}    esac
${pad}    ;;
''
        else
          ""
      ) tree);
    in body;

  # Top-level: create one function per root command (git, docker, etc.)
  renderCommand = cmd: subTree:
    ''
function ${cmd}() {
  case "$1" in
${renderTree 2 subTree}
    *)
      command ${cmd} "$@"
      ;;
  esac
}
'';

  allFunctions = lib.concatStringsSep "\n\n" (lib.mapAttrsToList renderCommand overrides);

  script = ''
#!/usr/bin/env bash
set -euo pipefail

# Generated override functions
${allFunctions}

# If sourced, just load the functions.
if [[ "${BASH_SOURCE[0]}" != "$0" ]]; then
  return 0
fi

cmd="$(basename "$0")"
if declare -f "$cmd" > /dev/null; then
  exec "$cmd" "$@"
else
  exec "$cmd" "$@"
fi
'';
in
{
}

