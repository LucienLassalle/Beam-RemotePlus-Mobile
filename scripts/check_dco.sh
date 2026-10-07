#!/usr/bin/env bash
# Developer Certificate of Origin check (https://developercertificate.org):
# every non-merge commit in BASE..HEAD must carry a "Signed-off-by:" trailer
# matching its author (git commit -s).
#
# Usage: scripts/check_dco.sh <base> <head>
set -euo pipefail

base="$1"
head="$2"
failed=0

for sha in $(git rev-list --no-merges "$base..$head"); do
  author="$(git log -1 --format='%an <%ae>' "$sha")"
  if ! git log -1 --format='%(trailers:key=Signed-off-by,valueonly)' "$sha" | grep -Fxq "$author"; then
    echo "::error::commit $sha is missing 'Signed-off-by: $author' (use git commit -s)"
    failed=1
  fi
done

if [[ $failed -ne 0 ]]; then
  echo "Fix with: git rebase --signoff $base && git push --force-with-lease"
  exit 1
fi
echo "DCO OK"
