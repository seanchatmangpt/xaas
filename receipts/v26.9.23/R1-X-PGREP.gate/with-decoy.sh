#!/bin/bash
# Run a command while ONE unrelated real process whose cmdline matches the old
# machine-wide survivor pattern ("zcode.js --prompt") is alive, then stop it.
# usage: with-decoy.sh <log> <command string>
# The command runs in /Users/sac/wt/v26922/v23/R1-X-PGREP under the xaas pin.
set -u
log="$1"; shift
cmd="$1"
cd /Users/sac/wt/v26922/v23/R1-X-PGREP || exit 99
/bin/bash -c 'exec -a "node bin/zcode.js --prompt /xaas R1-X-PGREP-external-decoy" /bin/sleep 1500' &
decoy=$!
sleep 0.5
{
  echo "## decoy pid $decoy started $(date -u +%FT%TZ)"
  echo "## pgrep -fl 'zcode.js --prompt' before:"
  pgrep -fl "zcode.js --prompt"
  echo "## HEAD $(git rev-parse HEAD) porcelain=[$(git status --porcelain | tr '\n' ' ')]"
  echo "## cmd: $cmd"
} > "$log" 2>&1
PATH=/Users/sac/.asdf/installs/elixir/1.20.2-otp-28/bin:/Users/sac/.asdf/installs/erlang/28.5.0.2/bin:$PATH \
  /bin/sh -c "$cmd" >> "$log" 2>&1
rc=$?
{
  echo "## exit $rc"
  if kill -0 "$decoy" 2>/dev/null; then echo "## decoy $decoy alive at end: yes"; else echo "## decoy $decoy alive at end: NO"; fi
  echo "## pgrep -fl 'zcode.js --prompt' after:"
  pgrep -fl "zcode.js --prompt"
} >> "$log" 2>&1
kill "$decoy" 2>/dev/null
wait "$decoy" 2>/dev/null
echo "## decoy stopped $(date -u +%FT%TZ)" >> "$log"
exit $rc
