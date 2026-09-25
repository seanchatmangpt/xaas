#!/bin/sh
# GC23-10 court: Cold Replay (PRD section 12, PR-013; ARD sections 7 and 16;
# falsifiers F5, F6; goal.ttl v23:GC23-10). Machinery: lane V23-R.
# Run by mix xaas.stop_court --checkpoint GC-26.9.23 from the xaas root with
# XAAS_DIR and GGEN_IGNITER_DIR in the env. Exit 0 = ALIVE; exit 75 = the
# court cannot witness (standing UNKNOWN); exit 1 = the court ran and refused.
#
# Every replay below is `mix xaas.replay` (Xaas.Ultracode.SemanticReplay)
# under the F3 cold environment: courts/no_llm_env.sh (env -i, fresh HOME,
# no model variable, no claude/zcode on PATH) inside a sandbox-exec profile
# that denies every read and write of the operator's ~/.claude. It rebuilds
# subject identity, evidence, standing, completed work and the frontier from
# the episode's receipts + TransitionLog + work graph + git refs only, with
# the graph side's own law (mix semantic_jira.xaas_receipt / reconcile /
# frontier, SemanticJira.replay_check/2) in GGEN_IGNITER_DIR under a private
# MIX_BUILD_PATH clone.
#
# Witnesses, over the committed reference episode fmt-1:
#   0. the recorded digest: episodes/fmt-1/replay.json is exactly the state
#      projected from the episode-time artifacts by the independent
#      courts/replay_project.py (python3; no graph side, no git);
#   1. fence anti-vacuity: under the profile, ~/.claude is unreadable;
#   2. two cold replays: exit 0 (KNOWN_REPLAY), byte-identical outputs, and
#      both digests equal the recorded digest;
#   3. F3: the replay with ANTHROPIC_API_KEY=x exposed is refused
#      REFUSED(llm_credential_present), broken term mu_on_O;
#   4. F5: a copy of the episode with receipt.json deleted diverges (exit 4):
#      EP-A is no longer ALIVE, the frontier differs, typed
#      unreceipted_transition / R_missing_replay;
#   5. F6: a commit after the receipt head that touches the order's
#      path_scope (lib/) demotes EP-A (exit 4, typed subject_changed /
#      R_missing_identity); control: a commit outside the path_scope (docs/)
#      keeps EP-A ALIVE and the recorded frontier (exit 0). Both commits are
#      made in a scratch repository whose objects are the subject
#      repository's (alternates); no shared ref is written.
set -u

xaas=${XAAS_DIR:-$(pwd)}
ggen=${GGEN_IGNITER_DIR:-$(cd "${XAAS_DIR:-$(pwd)}/.." && pwd)/ggen_igniter}
ep=${GC23_EPISODE_DIR:-$xaas/docs/sjira/v26.9.23/episodes/fmt-1}
cd "$xaas" || { echo "UNKNOWN: GC23-10 XAAS_DIR $xaas unreadable"; exit 75; }

for f in work.json ledger.ndjson receipt.json drive.json frontier_after.json replay.json; do
  [ -f "$ep/$f" ] || { echo "UNKNOWN: GC23-10 episode fmt-1 has no $f"; exit 75; }
done
[ -f "$xaas/lib/mix/tasks/xaas.replay.ex" ] || { echo "UNKNOWN: GC23-10 machinery lands in lane V23-R"; exit 75; }
for t in xaas_receipt reconcile frontier; do
  [ -f "$ggen/lib/mix/tasks/semantic_jira.$t.ex" ] || {
    echo "UNKNOWN: GC23-10 GGEN_IGNITER_DIR $ggen lacks mix semantic_jira.$t (the restored surface, FRI-T6)"
    exit 75
  }
done
command -v sandbox-exec >/dev/null 2>&1 || { echo "UNKNOWN: GC23-10 no sandbox-exec; cannot fence ~/.claude"; exit 75; }

tmp=$(mktemp -d "${TMPDIR:-/tmp}/gc23-10.XXXXXX")
trap 'rm -rf "$tmp"' EXIT INT TERM
refuse() { echo "REFUSED: GC23-10 $*"; exit 1; }
env_sh="$xaas/docs/sjira/v26.9.23/courts/no_llm_env.sh"
proj="$xaas/docs/sjira/v26.9.23/courts/replay_project.py"

# 0. the recorded digest is the episode-time projection
python3 "$proj" "$ep" --check "$ep/replay.json" || refuse "replay.json is not the projection of the episode-time artifacts"
recorded=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["digest"])' "$ep/replay.json")
ref=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["subject"]["pinned"])' "$ep/drive.json")
echo "recorded: $recorded (subject ref $ref)"

# 1. the ~/.claude fence, proven live
realhome=$HOME
claude_dir=$(cd "$realhome/.claude" 2>/dev/null && pwd -P || echo "$realhome/.claude")
profile="(version 1)(allow default)(deny file-read* file-write* (subpath \"$realhome/.claude\") (subpath \"$claude_dir\"))"
if [ -d "$claude_dir" ]; then
  if sandbox-exec -p "$profile" /bin/ls "$claude_dir" >/dev/null 2>&1; then
    echo "UNKNOWN: GC23-10 the sandbox profile does not fence $claude_dir"
    exit 75
  fi
  echo "fence: $claude_dir unreadable under the replay profile"
else
  echo "fence: $claude_dir absent"
fi

# private graph-side build, shared by every replay (nothing of the checkout is written)
mkdir -p "$tmp/build"
if [ -d "$ggen/_build/test" ]; then
  cp -cRp "$ggen/_build/test" "$tmp/build/" 2>/dev/null || cp -Rp "$ggen/_build/test" "$tmp/build/"
fi

# replay NAME EPISODE_DIR [extra mix xaas.replay args]; env assignments for
# no_llm_env.sh may precede NAME as ENV=NAME=value (only the F3 run uses it)
replay() {
  extra_env=""
  case "$1" in ENV=*) extra_env=${1#ENV=}; shift ;; esac
  name=$1; epdir=$2; shift 2
  mkdir -p "$tmp/$name"
  # shellcheck disable=SC2086
  MIX_ENV=test sandbox-exec -p "$profile" sh "$env_sh" $extra_env -- \
    mix xaas.replay --episode "$epdir" --ggen-igniter-dir "$ggen" \
    --ggen-build-path "$tmp/build/test" --scratch "$tmp/$name" \
    --out "$tmp/$name/state.json" "$@" >"$tmp/$name/log" 2>&1
  code=$?
  if [ "$code" = "75" ]; then tail -2 "$tmp/$name/log"; echo "UNKNOWN: GC23-10 no-LLM env unbuildable"; exit 75; fi
  if [ "$code" = "3" ] && grep -q '"standing":"BUILD_BROKEN"' "$tmp/$name/log"; then
    tail -1 "$tmp/$name/log"
    echo "UNKNOWN: GC23-10 the graph side in $ggen does not build under the resolved toolchain (BUILD_BROKEN)"
    exit 75
  fi
  echo "$code" >"$tmp/$name/exit"
}
exit_of() { cat "$tmp/$1/exit"; }

# 2. two cold replays
replay cold1 "$ep"
replay cold2 "$ep"
for run in cold1 cold2; do
  [ "$(exit_of $run)" = "0" ] || { tail -3 "$tmp/$run/log"; refuse "$run exited $(exit_of $run), not 0 (KNOWN_REPLAY)"; }
done
cmp -s "$tmp/cold1/state.json" "$tmp/cold2/state.json" || refuse "the two cold replays are not byte-identical"
python3 - "$tmp" "$recorded" "$claude_dir" <<'PY' || refuse "a cold replay digest differs from the recorded digest"
import hashlib, json, sys
tmp, recorded, claude = sys.argv[1], sys.argv[2], sys.argv[3]
for run in ("cold1", "cold2"):
    out = json.load(open(f"{tmp}/{run}/state.json", encoding="utf-8"))
    canon = json.dumps(out["state"], sort_keys=True, separators=(",", ":"), ensure_ascii=False)
    assert out["digest"] == "sha256:" + hashlib.sha256(canon.encode()).hexdigest(), f"{run}: digest does not recompute"
    assert out["digest"] == recorded, f"{run}: {out['digest']} != recorded {recorded}"
    assert out["replay"] == "KNOWN_REPLAY" and out["state"]["divergence"] == []
    classes = sorted({s["class"] for s in out["sources"]})
    assert classes == ["drive_record", "git_ref", "receipt", "transition_log", "work_graph"], classes
    assert not any(claude in json.dumps(s) for s in out["sources"]), "a source lives under ~/.claude"
s = out["state"]
print(f"cold: 2 runs, digest {out['digest']} == recorded; standing {s['standing']}, "
      f"completed {s['completed']}, eligible {s['frontier']['eligible']}")
PY

# 3. F3: an exposed model credential is refused by the guard
replay ENV=ANTHROPIC_API_KEY=x f3 "$ep"
[ "$(exit_of f3)" = "3" ] || refuse "F3: the replay with ANTHROPIC_API_KEY exposed exited $(exit_of f3), not 3"
tail -1 "$tmp/f3/log" | python3 -c '
import json, sys
t = json.loads(sys.stdin.read())
assert t["standing"] == "REFUSED(llm_credential_present)" and t["broken_term"] == "mu_on_O", t
assert "ANTHROPIC_API_KEY" in t["detail"]["variables"], t
print("F3: REFUSED(llm_credential_present), broken term mu_on_O")
' || refuse "F3: the exposed credential was not refused by the no-LLM guard"
[ ! -e "$tmp/f3/state.json" ] || refuse "F3: a refused replay wrote a state"

# 4. F5: delete the receipt
cp -R "$ep" "$tmp/f5-episode"
rm "$tmp/f5-episode/receipt.json"
replay f5 "$tmp/f5-episode"
[ "$(exit_of f5)" = "4" ] || { tail -3 "$tmp/f5/log"; refuse "F5: replay without receipt.json exited $(exit_of f5), not 4 (DIVERGED)"; }
python3 - "$tmp/f5/state.json" "$ep/replay.json" <<'PY' || refuse "F5: deleting the receipt did not diverge standing and frontier"
import json, sys
got, rec = json.load(open(sys.argv[1])), json.load(open(sys.argv[2]))
s, r = got["state"], rec["state"]
assert got["replay"] == "DIVERGED" and got["digest"] != rec["digest"]
assert r["standing"]["EP-A"] == "ALIVE" and s["standing"]["EP-A"] != "ALIVE", s["standing"]
assert s["frontier"] != r["frontier"] and "EP-A" in s["frontier"]["eligible"] and "EP-B" not in s["frontier"]["eligible"]
assert s["completed"] == [] and s["replay"]["status"] == "REFUSED"
typed = [(d["reason"], d["broken_term"], d["identity"]) for d in s["divergence"]]
assert ("unreceipted_transition", "R_missing_replay", "EP-A") in typed, typed
print(f"F5: EP-A {r['standing']['EP-A']} -> {s['standing']['EP-A']}, eligible {s['frontier']['eligible']}, typed {typed}")
PY

# 5. F6: change the covered subject after the receipt (scratch repo, shared objects)
common=$(cd "$ggen" && cd "$(git rev-parse --git-common-dir)" && pwd -P) || refuse "F6: no git common dir for $ggen"
head=$(git -C "$ggen" rev-parse --verify "$ref^{commit}") || refuse "F6: subject ref $ref absent in $ggen"
subject_repo() { # subject_repo NAME PATH_TOUCHED -> prints the repo dir; ref advanced by one commit
  r="$tmp/$1-subject"
  git init -q "$r" && echo "$common/objects" >"$r/.git/objects/info/alternates" || return 1
  git -C "$r" update-ref "refs/heads/$ref" "$head" || return 1
  idx="$tmp/$1.index"
  GIT_INDEX_FILE=$idx git -C "$r" read-tree "$head" || return 1
  blob=$(printf 'F6 touch of %s\n' "$2" | git -C "$r" hash-object -w --stdin) || return 1
  GIT_INDEX_FILE=$idx git -C "$r" update-index --add --cacheinfo "100644,$blob,$2" || return 1
  tree=$(GIT_INDEX_FILE=$idx git -C "$r" write-tree) || return 1
  commit=$(GIT_AUTHOR_NAME=gc23-10 GIT_AUTHOR_EMAIL=gc23-10@xaas.invalid GIT_AUTHOR_DATE=2026-09-23T00:00:00Z \
    GIT_COMMITTER_NAME=gc23-10 GIT_COMMITTER_EMAIL=gc23-10@xaas.invalid GIT_COMMITTER_DATE=2026-09-23T00:00:00Z \
    git -C "$r" commit-tree "$tree" -p "$head" -m "GC23-10 F6: touch $2") || return 1
  git -C "$r" update-ref "refs/heads/$ref" "$commit" "$head" || return 1
  echo "$r"
}
f6repo=$(subject_repo f6 lib/ggen_igniter/gc23_10_f6_touch.ex) || refuse "F6: could not build the scratch subject"
ctlrepo=$(subject_repo f6ctl docs/gc23_10_f6_control.md) || refuse "F6: could not build the control subject"
replay f6 "$ep" --subject-repo "$f6repo"
replay f6ctl "$ep" --subject-repo "$ctlrepo"
[ "$(exit_of f6)" = "4" ] || { tail -3 "$tmp/f6/log"; refuse "F6: a covered-path commit exited $(exit_of f6), not 4 (DIVERGED)"; }
[ "$(exit_of f6ctl)" = "0" ] || { tail -3 "$tmp/f6ctl/log"; refuse "F6 control: an out-of-scope commit exited $(exit_of f6ctl), not 0"; }
python3 - "$tmp/f6/state.json" "$tmp/f6ctl/state.json" "$ep/replay.json" <<'PY' || refuse "F6: the covered-subject change did not demote the ALIVE standing (or the control did)"
import json, sys
f6, ctl, rec = (json.load(open(p)) for p in sys.argv[1:4])
s, c, r = f6["state"], ctl["state"], rec["state"]
assert r["standing"]["EP-A"] == "ALIVE"
assert f6["replay"] == "DIVERGED" and s["standing"]["EP-A"] != "ALIVE", s["standing"]
assert s["subject"]["tip"] != r["subject"]["tip"]
ev = s["evidence"][0]
assert ev["current"] is False and ev["admitted"] is False
assert ev["changed_paths"] == ["lib/ggen_igniter/gc23_10_f6_touch.ex"], ev["changed_paths"]
typed = [(d["reason"], d["broken_term"], d["identity"]) for d in s["divergence"]]
assert ("subject_changed", "R_missing_identity", "EP-A") in typed, typed
assert ctl["replay"] == "KNOWN_REPLAY" and c["divergence"] == []
for k in ("standing", "completed", "frontier", "replay"):
    assert c[k] == r[k], f"control {k}: {c[k]!r} != recorded {r[k]!r}"
assert c["subject"]["tip"] != r["subject"]["tip"] and c["evidence"][0]["current"] is True
print(f"F6: covered commit -> EP-A {s['standing']['EP-A']} typed {typed}; "
      f"control (docs/ only) -> EP-A {c['standing']['EP-A']}, frontier as recorded")
PY

echo "ALIVE: GC23-10 cold replay of episode fmt-1 reproduces the recorded digest twice under the no-LLM, ~/.claude-fenced env; F3, F5 and F6 witnessed"
exit 0
