#!/usr/bin/env bash
# Real trivial "planner" stand-in for the primary step. Reads a single integer
# from stdin, sleeps briefly to simulate real compute, doubles it, writes the
# result to stdout. Exits 0 on success.
set -euo pipefail
read -r n
sleep 0.2
echo $((n * 2))
