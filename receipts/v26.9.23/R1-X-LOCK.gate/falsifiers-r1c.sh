#!/bin/sh
# R1-X-LOCK (release defect F1) falsifier harness, wave R1c.
# Exit 0 iff every falsifier fires exactly as expected at the checked-out subject:
#   FA  frozen subject e999e62 reproduces F1: `ggen sync run` exits 1 with FM-PACK-008
#   FB  revert-mutation: ggen.lock restored to e999e62 bytes makes projection_test.exs fail
#       (mix test exit 2, FM-PACK-008 in the output); the lock is restored afterwards
#   FC  generation path: an independent `ggen sync run` re-lock from the subject's inputs is
#       byte-identical to the committed lock and projection, and a second sync is a no-op
#   FD  Chicago: zero mock/patch matches under test/xaas/zcode_plugin/
# Usage: falsifiers-r1c.sh <xaas worktree> <scratch dir>
set -u
WT=${1:?xaas worktree}
SCR=${2:?scratch dir}
PIN=/Users/sac/.asdf/installs/elixir/1.20.2-otp-28/bin:/Users/sac/.asdf/installs/erlang/28.5.0.2/bin
LOCK=priv/zcode_plugin/ggen.lock
mkdir -p "$SCR"
cd "$WT" || exit 90
SUBJ=$(git rev-parse HEAD)
if [ -n "$(git status --porcelain -- . ':!receipts')" ]; then
  echo "REFUSED: product tree (outside receipts/) is not clean at $SUBJ"; exit 91
fi
echo "subject=$SUBJ ggen=$(ggen --version 2>/dev/null | head -1)"
fail=0

# FA
rm -rf "$SCR/fa" && mkdir -p "$SCR/fa"
git archive e999e62 priv/zcode_plugin | tar -x -C "$SCR/fa"
(cd "$SCR/fa/priv/zcode_plugin" && ggen sync run) > "$SCR/fa.log" 2>&1
ea=$?
if [ "$ea" -eq 1 ] && grep -q "FM-PACK-008" "$SCR/fa.log"; then fa=fired; else fa=MISSED; fail=1; fi
echo "FA frozen-subject reproduction: inner_exit=$ea expected=1+FM-PACK-008 -> $fa"

# FB
committed=$(shasum -a 256 "$LOCK" | cut -d' ' -f1)
trap 'git show HEAD:$LOCK > "$LOCK"' EXIT INT TERM
git show e999e62:$LOCK > "$LOCK"
PATH=$PIN:$PATH mix test test/xaas/zcode_plugin/projection_test.exs > "$SCR/fb.log" 2>&1
eb=$?
git show HEAD:$LOCK > "$LOCK"
trap - EXIT INT TERM
restored=$(shasum -a 256 "$LOCK" | cut -d' ' -f1)
if [ "$eb" -eq 2 ] && grep -q "FM-PACK-008" "$SCR/fb.log" && [ "$restored" = "$committed" ] \
   && [ -z "$(git status --porcelain -- . ':!receipts')" ]; then fb=fired; else fb=MISSED; fail=1; fi
echo "FB revert-mutation (lock -> e999e62 bytes): inner_exit=$eb expected=2+FM-PACK-008 restored_sha256=$restored -> $fb"

# FC
rm -rf "$SCR/fc" && mkdir -p "$SCR/fc"
git archive "$SUBJ" priv/zcode_plugin | tar -x -C "$SCR/fc"
(cd "$SCR/fc/priv/zcode_plugin" && rm ggen.lock && ggen sync run) > "$SCR/fc.log" 2>&1
ec1=$?
cmp -s "$SCR/fc/$LOCK" "$LOCK"; ec2=$?
diff -r "$SCR/fc/priv/zcode_plugin/marketplace" priv/zcode_plugin/marketplace > "$SCR/fc.diff" 2>&1; ec3=$?
(cd "$SCR/fc/priv/zcode_plugin" && ggen sync run) > "$SCR/fc2.log" 2>&1
ec4=$?
cmp -s "$SCR/fc/$LOCK" "$LOCK"; ec5=$?
if [ "$ec1$ec2$ec3$ec4$ec5" = "00000" ]; then fc=held; else fc=BROKEN; fail=1; fi
echo "FC re-lock determinism: sync=$ec1 cmp_lock=$ec2 diff_projection=$ec3 resync=$ec4 cmp_lock2=$ec5 -> $fc"

# FD
grep -rn "unittest.mock\|Mock(\|MagicMock\|patch(\|monkeypatch\|Mox\|:meck\|Mimic" test/xaas/zcode_plugin/
ed=$?
if [ "$ed" -eq 1 ]; then fd=held; else fd=BROKEN; fail=1; fi
echo "FD Chicago mock grep: inner_exit=$ed expected=1 (no match) -> $fd"

echo "RESULT fail=$fail"
exit $fail
