#!/bin/sh
# The operator-acceptance edge of the GC-26.9.24 successor prose (GC-26.9.23
# gate GC23-12, lane V23-H; PRD section 12, ARD section 24 M9).
#
#   sh docs/sjira/v26.9.23/courts/successor_acceptance.sh <xaas-dir>
#
# The successor prose docs/sjira/v26.9.23/successor/v26.9.24-wbpr.md is a
# DRAFT until the operator accepts it. Acceptance is one durable operator act:
# committing docs/sjira/v26.9.23/successor/ACCEPTED whose content names the
# prose's sha256 ("sha256:<hex>" or "<hex>"). No lane, court or agent writes
# that file.
#
# Exit 0 and "ACCEPTED: ..." when ACCEPTED is committed at HEAD, unmodified,
# and names the sha256 of the committed, unmodified prose. Exit 77 (the stop
# court's blocked_exit) with the typed last line
#   BLOCKED(operator_acceptance): ... (broken_term R_missing_authority)
# when ACCEPTED is absent, uncommitted, modified, or names another digest
# (a stale acceptance of different bytes): the successor's admission lacks
# the operator's grant. Exit 1 (REFUSED) when the prose itself is not
# committed or differs from HEAD (there are no exact bytes to accept).
set -u

xaas=${1:?usage: successor_acceptance.sh <xaas-dir>}
prose=docs/sjira/v26.9.23/successor/v26.9.24-wbpr.md
accepted=docs/sjira/v26.9.23/successor/ACCEPTED

git -C "$xaas" ls-files --error-unmatch "$prose" >/dev/null 2>&1 || {
  echo "REFUSED: GC23-12 successor prose $prose is not committed in $xaas"
  exit 1
}
git -C "$xaas" diff --quiet HEAD -- "$prose" || {
  echo "REFUSED: GC23-12 successor prose $prose differs from its committed bytes at HEAD"
  exit 1
}
sha=$(python3 -c 'import hashlib,sys; print(hashlib.sha256(open(sys.argv[1],"rb").read()).hexdigest())' "$xaas/$prose") || {
  echo "REFUSED: GC23-12 cannot digest $prose"
  exit 1
}

blocked() {
  echo "BLOCKED(operator_acceptance): GC23-12 successor prose sha256:$sha awaits the operator: $1 (broken_term R_missing_authority)"
  exit 77
}

if ! git -C "$xaas" ls-files --error-unmatch "$accepted" >/dev/null 2>&1; then
  if [ -e "$xaas/$accepted" ]; then
    blocked "$accepted exists but is not committed"
  fi
  blocked "$accepted is absent"
fi
git -C "$xaas" diff --quiet HEAD -- "$accepted" || blocked "$accepted differs from its committed bytes"
grep -Eq "(^|[^0-9a-f])$sha([^0-9a-f]|\$)" "$xaas/$accepted" ||
  blocked "$accepted names no sha256 of the current prose (stale acceptance)"

echo "ACCEPTED: GC23-12 successor prose sha256:$sha accepted by the operator ($accepted committed at $(git -C "$xaas" rev-parse HEAD))"
exit 0
