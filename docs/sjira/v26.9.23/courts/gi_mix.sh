#!/bin/sh
# Runs `mix <task> [args ...]` inside the ggen_igniter checkout under
# judgement (GGEN_IGNITER_DIR, default the ggen_igniter-int worktree) under the
# F3 no-LLM court environment of courts/no_llm_env.sh (env -i, a fresh HOME,
# no ANTHROPIC_/CLAUDE_/OPENAI_/ZAI_/Z_AI_/GLM_/ZCODE_ variable, no claude or
# zcode executable on PATH), with MIX_ENV=test unless GI_MIX_ENV names another
# build. Lane V23-K; used by the GC23-0, GC23-2 and GC23-3 courts, which pass
# absolute paths (the mix task runs with the ggen_igniter root as its cwd).
#
# The judged checkout is read, never written: mix runs with MIX_BUILD_PATH set
# to a private APFS clone (cp -c; plain copy as fallback) of
# $GGEN_IGNITER_DIR/_build/$MIX_ENV, removed on exit, so a stale build is
# recompiled into the clone and concurrent courts never race on the judged
# checkout's _build (the GC23-8/GC23-9/GC23-10 courts do the same).
#
#   sh docs/sjira/v26.9.23/courts/gi_mix.sh semantic_jira.compile_prose --check ...
#
# The graph-side toolchain is the drive's own resolution (ARD section 14,
# Xaas.Ultracode.SemanticDrive.graph_toolchain/2 via `mix xaas.episode
# --graph-toolchain`, the call GC23-8 and GC23-9 make): the Elixir that
# compiled the build under judgement on the ERTS it was compiled on, else the
# checkout's .tool-versions pin, resolved in the xaas checkout these courts
# belong to and put first on the PATH the no-LLM environment is built from.
# So GC23-0/2/3/12 and the drive judge one ggen_igniter build with one
# compiler (R1-X-PIN: under the xaas pin 1.20.2-otp-28 the caller's mix
# recompiled a ggen_igniter-int _build/test built by its own pin
# 1.18.4-otp-27 from scratch and failed on faker). Court scripts copied
# outside an xaas checkout keep the caller's PATH and say so.
#
# Exit: the mix exit code; 75 (UNKNOWN) when GGEN_IGNITER_DIR is not a mix
# project, no graph-side toolchain resolves, or the no-LLM environment cannot
# be built.
set -u

here=$(cd "$(dirname "$0")" && pwd)
gi=${GGEN_IGNITER_DIR:-/Users/sac/wt/v26922/fri/ggen_igniter-int}

if [ ! -f "$gi/mix.exs" ]; then
  echo "UNKNOWN: gi_mix: GGEN_IGNITER_DIR $gi is not a mix project"
  exit 75
fi

MIX_ENV=${GI_MIX_ENV:-test}
export MIX_ENV

build=$(mktemp -d "${TMPDIR:-/tmp}/gi-mix-build.XXXXXX") || {
  echo "UNKNOWN: gi_mix: cannot create a private build dir"
  exit 75
}
trap 'rm -rf "$build"' EXIT
trap 'exit 75' INT TERM
if [ -d "$gi/_build/$MIX_ENV" ]; then
  if ! cp -cRp "$gi/_build/$MIX_ENV" "$build/$MIX_ENV" 2>/dev/null; then
    rm -rf "$build/$MIX_ENV"
    cp -Rp "$gi/_build/$MIX_ENV" "$build/$MIX_ENV" || {
      echo "UNKNOWN: gi_mix: cannot copy $gi/_build/$MIX_ENV into a private build dir"
      exit 75
    }
  fi
fi

root=$(cd "$here/../../../.." && pwd)
if [ -f "$root/mix.exs" ] && [ -f "$root/lib/mix/tasks/xaas.episode.ex" ]; then
  (cd "$root" && env MIX_ENV=test mix xaas.episode --graph-toolchain \
    --ggen-igniter-dir "$gi" --ggen-build-path "$build/$MIX_ENV" </dev/null) \
    >"$build/toolchain.log" 2>&1 || {
    tail -5 "$build/toolchain.log"
    echo "UNKNOWN: gi_mix: no graph-side toolchain resolves for $gi"
    exit 75
  }
  resolved=$(python3 -I - "$build/toolchain.log" <<'PY'
import json, os, sys
for line in reversed(open(sys.argv[1], encoding="utf-8").read().splitlines()):
    line = line.strip()
    if line.startswith("{"):
        t = json.loads(line)
        break
else:
    raise SystemExit("no toolchain JSON")
print(os.path.dirname(t["mix"]) + ":" + os.path.dirname(t["erl"]))
print(f"{t['source']} elixir {t['elixir']} erlang {t['erlang']} ({t['mix']})")
PY
  ) || {
    echo "UNKNOWN: gi_mix: unreadable graph-side toolchain for $gi"
    exit 75
  }
  PATH="$(printf '%s\n' "$resolved" | sed -n 1p):$PATH"
  export PATH
  echo "gi_mix: graph-side toolchain: $(printf '%s\n' "$resolved" | sed -n 2p)"
else
  echo "gi_mix: graph-side toolchain: the caller's PATH (these courts are not inside an xaas checkout: $root)"
fi

sh "$here/no_llm_env.sh" MIX_BUILD_PATH="$build/$MIX_ENV" -- \
  sh -c 'cd "$0" && exec mix "$@"' "$gi" "$@"
code=$?
exit "$code"
