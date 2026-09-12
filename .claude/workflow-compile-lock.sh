#!/usr/bin/env bash
# Real file-based mutex for compile-heavy workflow stages.
#
# Implements the mechanism described (previously as doc-only convention) in
# .claude/workflow-lock-guard.md:21-27 — a real acquire/release/check helper
# backed by /Users/sac/xaas/.claude/.workflow-compile.lock, with PID liveness
# checking (stale locks from a dead process are reclaimed) and a trap-based
# release so a script that dies mid-stage doesn't leave a stuck lock forever.
#
# Usage (source this file, then call the functions):
#   source .claude/workflow-compile-lock.sh
#   workflow_lock_acquire "my-label"   # blocks (with backoff) until acquired,
#                                       # installs an EXIT trap to release it
#   ... run mix compile --force / mix test ...
#   workflow_lock_release              # explicit release (trap also covers it)
#
# Or as a standalone CLI:
#   .claude/workflow-compile-lock.sh acquire "my-label" [timeout_seconds]
#   .claude/workflow-compile-lock.sh release
#   .claude/workflow-compile-lock.sh check

set -u

WORKFLOW_LOCK_FILE="${WORKFLOW_LOCK_FILE:-/Users/sac/xaas/.claude/.workflow-compile.lock}"

# Returns 0 (true) if the given PID is a live process, 1 otherwise.
workflow_lock_pid_alive() {
  local pid="$1"
  [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null
}

# Prints "held:<pid>:<timestamp>:<label>" if a live lock exists, else "free".
workflow_lock_check() {
  if [[ -f "$WORKFLOW_LOCK_FILE" ]]; then
    local contents pid
    contents="$(cat "$WORKFLOW_LOCK_FILE" 2>/dev/null)"
    pid="${contents%%:*}"
    if workflow_lock_pid_alive "$pid"; then
      echo "held:${contents}"
      return 0
    fi
  fi
  echo "free"
  return 1
}

# Acquire the lock, blocking with backoff until free or timeout (default 600s).
# On success, writes <pid>:<timestamp>:<label> and installs an EXIT trap that
# releases the lock automatically (covers normal exit, error exit, or signal).
workflow_lock_acquire() {
  local label="${1:-workflow}"
  local timeout="${2:-600}"
  local waited=0
  local interval=2

  while true; do
    if [[ -f "$WORKFLOW_LOCK_FILE" ]]; then
      local contents pid
      contents="$(cat "$WORKFLOW_LOCK_FILE" 2>/dev/null)"
      pid="${contents%%:*}"
      if workflow_lock_pid_alive "$pid"; then
        if (( waited >= timeout )); then
          echo "workflow_lock_acquire: timed out after ${timeout}s waiting on ${WORKFLOW_LOCK_FILE} (held by ${contents})" >&2
          return 1
        fi
        sleep "$interval"
        waited=$(( waited + interval ))
        continue
      else
        echo "workflow_lock_acquire: reclaiming stale lock (dead pid ${pid}): ${contents}" >&2
        rm -f "$WORKFLOW_LOCK_FILE"
      fi
    fi

    # Atomic create: fails if another process created it between our check and here.
    if ( set -o noclobber; echo "$$:$(date +%s):${label}" > "$WORKFLOW_LOCK_FILE" ) 2>/dev/null; then
      trap 'workflow_lock_release' EXIT INT TERM
      return 0
    fi
    # Lost the race; loop and re-check.
    sleep 0.2
  done
}

# Release the lock, but only if we still own it (pid matches our $$).
workflow_lock_release() {
  if [[ -f "$WORKFLOW_LOCK_FILE" ]]; then
    local contents pid
    contents="$(cat "$WORKFLOW_LOCK_FILE" 2>/dev/null)"
    pid="${contents%%:*}"
    if [[ "$pid" == "$$" ]]; then
      rm -f "$WORKFLOW_LOCK_FILE"
    fi
  fi
}

# Standalone CLI dispatch (only runs when executed directly, not when sourced).
if [[ "${BASH_SOURCE[0]:-}" == "${0}" ]]; then
  case "${1:-}" in
    acquire)
      workflow_lock_acquire "${2:-workflow}" "${3:-600}"
      exit $?
      ;;
    release)
      workflow_lock_release
      ;;
    check)
      workflow_lock_check
      ;;
    *)
      echo "usage: $0 {acquire <label> [timeout_s]|release|check}" >&2
      exit 2
      ;;
  esac
fi
