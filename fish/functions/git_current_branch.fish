set -l ref (command git symbolic-ref --short HEAD 2>/dev/null)
if test -n "$ref"
  echo $ref
  return 0
end

set ref (command git rev-parse --short HEAD 2>/dev/null)
if test -n "$ref"
  echo $ref
  return 0
end

return 1
