#!/bin/sh
# GC23-6 court: Consequence (PRD section 12, PR-011; ARD section 18;
# goal.ttl v23:GC23-6). Machinery: lane V23-D.
# Run by mix xaas.stop_court --checkpoint GC-26.9.23 from the xaas root with
# XAAS_DIR and GGEN_IGNITER_DIR in the env. Exit 0 = ALIVE; exit 75 = the
# court cannot witness (standing UNKNOWN); exit 1 = the court ran and refused.
#
# An independent observation, not the executor's claim: the court clones the
# ggen_igniter repository of GGEN_IGNITER_DIR (shared objects, nothing of that
# checkout is written), checks out the episode receipt's head in a FRESH tree
# and runs the postcondition itself -- `mix format --check-formatted` under
# the toolchain the subject's .tool-versions pins, `env -i` with a throwaway
# HOME:
#   1. the receipt head is the recipe-worker's single commit on top of the
#      episode subject (work.json EP-A base_sha), touching only path_scope;
#   2. at the receipt head the check exits 0;
#   3. F4 revert falsifier: with the recipe commit reverted the SAME check
#      exits non-zero (the court observes this order's consequence), and so
#      does the untouched subject (the drift is real);
#   4. the drive's own recorded verification (verification.json) agrees:
#      independent pass at the head, revert falsifier killed.
set -u

xaas=${XAAS_DIR:-$(pwd)}
ggen=${GGEN_IGNITER_DIR:-/Users/sac/wt/v26922/fri/ggen_igniter-int}
ep=${GC23_EPISODE_DIR:-$xaas/docs/sjira/v26.9.23/episodes/fmt-1}
asdf=${ASDF_DATA_DIR:-$HOME/.asdf}

for f in receipt.json work.json verification.json; do
  [ -f "$ep/$f" ] || { echo "UNKNOWN: GC23-6 episode fmt-1 has no $f (episode not driven)"; exit 75; }
done

tmp=$(mktemp -d "${TMPDIR:-/tmp}/gc23-6.XXXXXX")
trap 'rm -rf "$tmp"' EXIT INT TERM
refuse() { echo "REFUSED: GC23-6 $*"; exit 1; }

head=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["final_head"])' "$ep/receipt.json")
base=$(python3 -c '
import json, sys
w = json.load(open(sys.argv[1]))
print(next(r["base_sha"] for r in w["work_orders"] if r["identity"] == "EP-A"))' "$ep/work.json")

git -C "$ggen" cat-file -e "$head^{commit}" 2>/dev/null ||
  { echo "UNKNOWN: GC23-6 GGEN_IGNITER_DIR $ggen does not hold receipt head $head"; exit 75; }

git clone -q --shared --no-checkout "$ggen" "$tmp/fresh" 2>"$tmp/clone.log" ||
  { cat "$tmp/clone.log"; echo "UNKNOWN: GC23-6 cannot clone $ggen"; exit 75; }
g() { git -C "$tmp/fresh" -c core.hooksPath=/dev/null -c commit.gpgsign=false "$@"; }

# 1. shape of the consequence
parent=$(g rev-parse "$head^") || refuse "receipt head has no parent"
[ "$parent" = "$base" ] || refuse "receipt head parent $parent is not the episode subject $base"
[ "$(g rev-list --count "$base..$head")" = "1" ] || refuse "receipt head is not one commit on the subject"
author=$(g log -1 --format=%an "$head")
[ "$author" = "recipe-worker" ] || refuse "receipt head author is $author, not recipe-worker"
g diff --name-only "$base" "$head" >"$tmp/files" || refuse "cannot diff the consequence"
[ -s "$tmp/files" ] || refuse "the consequence changes no file"
python3 - "$ep/work.json" "$tmp/files" <<'PY' || refuse "the consequence touches a path outside EP-A path_scope"
import json, sys
row = next(r for r in json.load(open(sys.argv[1]))["work_orders"] if r["identity"] == "EP-A")
scope = row["path_scope"]
for f in open(sys.argv[2]).read().split():
    assert any(f == s or f.startswith(s.rstrip("/") + "/") for s in scope), f
PY

# the postcondition, run by the court itself
check() {
  g checkout -q --detach "$1" || return 97
  pins="$tmp/fresh/.tool-versions"
  elixir=$(awk '$1 == "elixir" { print $2 }' "$pins" 2>/dev/null)
  erlang=$(awk '$1 == "erlang" { print $2 }' "$pins" 2>/dev/null)
  ebin="$asdf/installs/elixir/$elixir/bin"
  obin="$asdf/installs/erlang/$erlang/bin"
  [ -x "$ebin/mix" ] && [ -x "$obin/erl" ] || return 98
  mkdir -p "$tmp/home"
  (cd "$tmp/fresh" && env -i HOME="$tmp/home" PATH="$ebin:$obin:/usr/bin:/bin" LANG=en_US.UTF-8 \
    MIX_ENV=test mix format --check-formatted) >"$tmp/check-$1.log" 2>&1
}

# 2. the postcondition holds at the receipt head
check "$head"
code=$?
case "$code" in
  0) echo "check at receipt head $head: exit 0" ;;
  97) refuse "cannot check out $head" ;;
  98) echo "UNKNOWN: GC23-6 the subject's pinned toolchain is not installed under $asdf"; exit 75 ;;
  *) tail -5 "$tmp/check-$head.log"; refuse "mix format --check-formatted exited $code at the receipt head" ;;
esac

# 3. F4: remove the consequence -> the same court fails
g checkout -q --detach "$head" && g revert --no-edit "$head" >/dev/null 2>&1 ||
  refuse "cannot revert the recipe commit"
reverted=$(g rev-parse HEAD)
check "$reverted"
code=$?
[ "$code" != "0" ] && [ "$code" != "97" ] && [ "$code" != "98" ] ||
  refuse "F4: with the recipe commit reverted the check exited $code (the court does not observe the consequence)"
echo "F4 revert falsifier at $reverted: exit $code (killed)"
check "$base"
code=$?
[ "$code" != "0" ] && [ "$code" != "97" ] && [ "$code" != "98" ] ||
  refuse "the episode subject $base passes the check (no drift to repair)"
echo "episode subject $base: exit $code (drift observed)"

# 4. the drive's recorded verification agrees
python3 - "$ep/verification.json" "$head" <<'PY' || refuse "verification.json disagrees with the court"
import json, sys
v = json.load(open(sys.argv[1])); head = sys.argv[2]
assert v["head"] == head
ind = v["independent"]
assert ind["status"] == "pass" and ind["head"] == head, ind.get("status")
assert all(x is True for x in ind["court_receipt"]["acceptance_results"].values())
f = v["revert_falsifier"]
assert f["verdict"] == "killed" and f["court"]["status"] == "fail" and f["reverted_commit"] == head
print("verification.json: independent pass, revert falsifier killed")
PY

echo "ALIVE: GC23-6 consequence independently observed at $head; F4 revert falsifier killed"
exit 0
