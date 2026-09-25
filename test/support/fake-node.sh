#!/bin/sh
# Real, simple implementation of the `node` executable's version contract:
# answers `--version` like node does, otherwise runs its arguments under
# /bin/sh (the fake zcode launchers in the dispatch tests are shell scripts).
# Not an interaction mock: it implements the two behaviours the dispatcher
# exercises, with real exit codes.
if [ "$1" = "--version" ]; then echo "v26.8.1"; exit 0; fi
exec /bin/sh "$@"
