#!/bin/sh
# The F3 no-LLM court environment (GC-26.9.23; PRD PR-009; lane V23-D).
#
#   sh docs/sjira/v26.9.23/courts/no_llm_env.sh [NAME=value ...] -- command [args ...]
#
# Runs the command under `env -i` with ONLY:
#   HOME           a fresh mktemp dir (removed afterwards);
#   PATH           the directories of the caller's mix, erl, git and python3,
#                  plus /usr/bin:/bin -- and refuses (exit 75, UNKNOWN) when
#                  any of them holds a `claude` or `zcode` executable;
#   MIX_HOME, HEX_HOME, ASDF_DATA_DIR
#                  durable toolchain configuration (not credentials), from
#                  the caller's values or their ~ defaults;
#   MIX_ENV, MIX_TEST_PARTITION, DEV_DB_USERNAME, DEV_DB_PASSWORD,
#   DEV_DB_HOSTNAME, DEV_DB_PORT, LANG
#                  passed through when set (the database URL parts are
#                  durable configuration of the local test database);
#   NAME=value     each assignment given before `--`.
# No ANTHROPIC_*, CLAUDE_*, CLAUDECODE, OPENAI_*, ZAI_*, Z_AI_*, GLM_* or
# ZCODE_* variable survives unless named explicitly before `--` (the F3
# court does exactly that to prove the guard refuses it).
set -u

extra=""
while [ $# -gt 0 ] && [ "$1" != "--" ]; do
  case "$1" in
    *=*) extra="$extra $1" ;;
    *) echo "no_llm_env: expected NAME=value or --, got: $1" >&2; exit 2 ;;
  esac
  shift
done
[ "${1:-}" = "--" ] || { echo "no_llm_env: missing -- before the command" >&2; exit 2; }
shift

path=""
for tool in mix erl git python3; do
  bin=$(command -v "$tool" 2>/dev/null) || { echo "UNKNOWN: no_llm_env: $tool not on PATH"; exit 75; }
  dir=$(dirname "$bin")
  for llm in claude zcode; do
    if [ -x "$dir/$llm" ]; then
      echo "UNKNOWN: no_llm_env: $dir holds $llm; cannot build a no-LLM PATH"
      exit 75
    fi
  done
  case ":$path:" in
    *":$dir:"*) ;;
    *) path="${path:+$path:}$dir" ;;
  esac
done
path="$path:/usr/bin:/bin"

home=$(mktemp -d "${TMPDIR:-/tmp}/no-llm-home.XXXXXX")
trap 'rm -rf "$home"' EXIT INT TERM

set -- env -i \
  "HOME=$home" \
  "PATH=$path" \
  "MIX_HOME=${MIX_HOME:-$HOME/.mix}" \
  "HEX_HOME=${HEX_HOME:-$HOME/.hex}" \
  "ASDF_DATA_DIR=${ASDF_DATA_DIR:-$HOME/.asdf}" \
  "LANG=${LANG:-en_US.UTF-8}" \
  ${MIX_ENV:+"MIX_ENV=$MIX_ENV"} \
  ${MIX_TEST_PARTITION:+"MIX_TEST_PARTITION=$MIX_TEST_PARTITION"} \
  ${DEV_DB_USERNAME:+"DEV_DB_USERNAME=$DEV_DB_USERNAME"} \
  ${DEV_DB_PASSWORD:+"DEV_DB_PASSWORD=$DEV_DB_PASSWORD"} \
  ${DEV_DB_HOSTNAME:+"DEV_DB_HOSTNAME=$DEV_DB_HOSTNAME"} \
  ${DEV_DB_PORT:+"DEV_DB_PORT=$DEV_DB_PORT"} \
  $extra \
  "$@"

"$@"
