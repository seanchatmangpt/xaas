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
# Exit: the mix exit code; 75 (UNKNOWN) when GGEN_IGNITER_DIR is not a mix
# project or the no-LLM environment cannot be built.
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

sh "$here/no_llm_env.sh" MIX_BUILD_PATH="$build/$MIX_ENV" -- \
  sh -c 'cd "$0" && exec mix "$@"' "$gi" "$@"
code=$?
exit "$code"
