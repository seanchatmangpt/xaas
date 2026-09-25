#!/usr/bin/env bash
# Real trivial "planner" stand-in that deliberately fails (nonzero exit) after
# consuming its stdin, so the ordered-fallback + compensate/4 path has a real
# process and a real failure to react to.
set -euo pipefail
read -r n
sleep 0.2
echo "primary planner deliberately failed for input=${n}" >&2
exit 7
