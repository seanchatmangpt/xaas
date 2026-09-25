#!/usr/bin/env bash
# Real script that reads its input, then sleeps far longer than any of this
# demo's step timeouts -- used to prove compensate/4 kills a genuinely still
# running OS process (not one that has already exited on its own).
set -euo pipefail
read -r n
sleep 30
echo "$n"
