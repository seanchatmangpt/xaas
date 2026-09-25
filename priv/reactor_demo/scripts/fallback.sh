#!/usr/bin/env bash
# Real trivial "planner" stand-in for the fallback step. Reads a single
# integer from stdin, sleeps briefly, triples it, writes the result to stdout.
set -euo pipefail
read -r n
sleep 0.2
echo $((n * 3))
