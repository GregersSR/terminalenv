command git rev-parse --git-dir >/dev/null 2>&1; or return

for branch in dev devel develop development
  if command git show-ref -q --verify refs/heads/$branch
    echo $branch
    return 0
  end
end

echo develop
return 1
