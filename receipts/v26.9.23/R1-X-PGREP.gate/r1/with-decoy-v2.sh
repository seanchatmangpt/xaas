#!/bin/bash
# Run a command while ONE unrelated real process whose cmdline matches the old
# machine-wide survivor pattern ("zcode.js --prompt") is alive, then stop it.
# v2 (repair round 1): the decoy is a precondition, not an assumption. The
# command runs only after `pgrep -f "zcode.js --prompt"` returns the decoy pid
# (polled up to 20 s). Otherwise the harness exits 98 without running the
# command. Visibility is checked again right after the command, and the
# harness exits 97 if the decoy is not alive and visible then, whatever the
# command's own exit was.
# The b8fe52f version (with-decoy.sh) only logged the pgrep output. In v2 the
# decoy's visibility is checked, and the harness fails closed when it is not
# visible, so a run whose decoy never matched the old pattern cannot pass.
# usage: with-decoy-v2.sh <log> <command string>
# The command runs in /Users/sac/wt/v26922/v23/R1-X-PGREP under the xaas pin.
set -u
log="$1"; shift
cmd="$1"
pattern="zcode.js --prompt"
cd /Users/sac/wt/v26922/v23/R1-X-PGREP || exit 99
/bin/bash -c 'exec -a "node bin/zcode.js --prompt /xaas R1-X-PGREP-external-decoy" /bin/sleep 1500' &
decoy=$!
visible() { pgrep -f "$pattern" | grep -qx "$decoy"; }
seen=no
for _ in $(seq 1 100); do
  if visible; then seen=yes; break; fi
  sleep 0.2
done
{
  echo "## decoy pid $decoy started $(date -u +%FT%TZ)"
  echo "## decoy visible to pgrep -f '$pattern' before: $seen"
  ps -o pid,pgid,command -p "$decoy"
  echo "## pgrep -fl '$pattern' before:"
  pgrep -fl "$pattern"
  echo "## HEAD $(git rev-parse HEAD) porcelain=[$(git status --porcelain | tr '\n' ' ')]"
  echo "## cmd: $cmd"
} > "$log" 2>&1
if [ "$seen" != yes ]; then
  echo "## REFUSED: decoy not visible to the old pattern; command not run" >> "$log"
  kill "$decoy" 2>/dev/null; wait "$decoy" 2>/dev/null
  exit 98
fi
PATH=/Users/sac/.asdf/installs/elixir/1.20.2-otp-28/bin:/Users/sac/.asdf/installs/erlang/28.5.0.2/bin:$PATH \
  /bin/sh -c "$cmd" >> "$log" 2>&1
rc=$?
after=no
if kill -0 "$decoy" 2>/dev/null && visible; then after=yes; fi
{
  echo "## exit $rc"
  echo "## decoy $decoy alive and visible to pgrep -f '$pattern' at end: $after"
  echo "## pgrep -fl '$pattern' after:"
  pgrep -fl "$pattern"
} >> "$log" 2>&1
kill "$decoy" 2>/dev/null
wait "$decoy" 2>/dev/null
echo "## decoy stopped $(date -u +%FT%TZ)" >> "$log"
if [ "$after" != yes ]; then echo "## REFUSED: decoy not alive+visible after the command" >> "$log"; exit 97; fi
exit $rc
