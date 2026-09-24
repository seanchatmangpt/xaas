#!/bin/sh
# R1-X-PIN revert-mutation falsifiers (lane R1-X-PIN, wave R1c).
#
#   sh falsify.sh <worktree> <scratch> <name>
#
# Each falsifier applies ONE mutation to the committed subject in <worktree>
# (the lane's own worktree, product tree clean before), runs the check that
# must now fail, restores every mutated path byte-for-byte from HEAD
# (`git show HEAD:<path> > <path>`), and asserts the product tree is clean
# again. Exit 0 iff the mutated check failed the expected way (the
# acceptance is not vacuous); 90 = the mutation was NOT caught; 91 = the tree
# was dirty before or after. Inner logs: <scratch>/falsify-<name>.inner.log.
#
# Names:
#   nil-clauses     restore the two `nil -> []` clauses in machine_experience.ex
#                   and `is_map(hops) &&` in xaas.episode.ex -> dialyzer exit 2
#                   with pattern_match at machine_experience.ex:539/:1235 and
#                   guard_fail at xaas.episode.ex:191
#   rproj-guard     remove the per-test @needs_validator guard -> the empty-HOME
#                   clause reports 5 failures
#   manifest-vsn1   manifest reader matches only vsn 1 {_, {e, o}, _} -> the
#                   pinned (vsn 2) toolchain tests fail
#   manifest-any    manifest reader = the c68c74d one (any 3-/4-tuple by
#                   position) -> the undeclared-shape test fails
#   gi-mix          gi_mix.sh without graph-side toolchain resolution -> the
#                   GC23-0 court under the xaas pin is not ALIVE (exit != 0)
#   court-policy    court_repo/1 without priv/no_llm/policy.json -> the GC23-0 /
#                   GC23-3 court-copy tests fail
#   port-hash       the undo OCEL test back on its hash-derived port while every
#                   port of that range is held -> :eaddrinuse; the committed
#                   test passes under the same held range (run by the caller
#                   with name port-held-committed)
set -u
wt=$1
scratch=$2
name=$3
pin=/Users/sac/.asdf/installs/elixir/1.20.2-otp-28/bin:/Users/sac/.asdf/installs/erlang/28.5.0.2/bin
gi=/Users/sac/wt/v26922/fri/ggen_igniter-int
inner="$scratch/falsify-$name.inner.log"
cd "$wt" || exit 91

clean() { [ -z "$(git status --porcelain --untracked-files=no)" ]; }
clean || { echo "DIRTY before $name"; git status --porcelain; exit 91; }
paths=""
restore() {
  for p in $paths; do git show "HEAD:$p" >"$p"; done
  clean || { echo "DIRTY after $name"; git status --porcelain; exit 91; }
  echo "restored: $paths (tree clean)"
}
mutate() { # mutate <path> <python replace script reading stdin old/new pairs>
  paths="$paths $1"
  python3 - "$1" || { echo "mutation of $1 failed"; restore; exit 91; }
}

case "$name" in
nil-clauses)
  mutate lib/xaas/ultracode/machine_experience.ex <<'PY'
import sys
p = sys.argv[1]; s = open(p).read()
pairs = [
 ("        graph |> RDF.Graph.description(subject) |> RDF.Description.triples()\n",
  "        case RDF.Graph.description(graph, subject) do\n          nil -> []\n          description -> RDF.Description.triples(description)\n        end\n"),
 ("    graph\n    |> RDF.Graph.description(subject)\n    |> RDF.Description.get(RDF.iri(property), [])\n    |> Enum.sort()\n",
  "    case RDF.Graph.description(graph, subject) do\n      nil -> []\n      description -> description |> RDF.Description.get(RDF.iri(property), []) |> Enum.sort()\n    end\n"),
]
for o, n in pairs:
    assert s.count(o) == 1, o
    s = s.replace(o, n)
open(p, "w").write(s)
PY
  mutate lib/mix/tasks/xaas.episode.ex <<'PY'
import sys
p = sys.argv[1]; s = open(p).read()
o = '''          # hops is the map SemanticDrive.verify_hops/1 already admitted
          order: opts[:order] || hops["work_order"] || "EP-A",'''
n = '''          order: opts[:order] || (is_map(hops) && hops["work_order"]) || "EP-A",'''
assert s.count(o) == 1
open(p, "w").write(s.replace(o, n))
PY
  env PATH="$pin:$PATH" sh -c 'MIX_ENV=dev mix deps.compile --force postgrex && MIX_ENV=dev mix dialyzer --format github' >"$inner" 2>&1
  code=$?
  restore
  grep -E '^Total errors|^::warning' "$inner"
  echo "inner_exit=$code"
  [ "$code" = 2 ] &&
    grep -q 'file=lib/xaas/ultracode/machine_experience.ex,line=539,.*title=pattern_match' "$inner" &&
    grep -q 'file=lib/xaas/ultracode/machine_experience.ex,line=1235,.*title=pattern_match' "$inner" &&
    grep -q 'file=lib/mix/tasks/xaas.episode.ex,line=191,title=guard_fail' "$inner" || exit 90
  ;;
rproj-guard)
  mutate test/xaas/receipt/r_projection_test.exs <<'PY'
import re, sys
p = sys.argv[1]; s = open(p).read()
n0 = s.count("  @tag skip: @needs_validator\n")
assert n0 == 5, n0
open(p, "w").write(s.replace("  @tag skip: @needs_validator\n", ""))
PY
  t=$(mktemp -d "$scratch/emptyhome.XXXXXX")
  env PATH="$pin:$PATH" HOME="$t" MIX_HOME=/Users/sac/.mix HEX_HOME=/Users/sac/.hex MIX_ENV=test \
    mix test test/xaas/receipt/r_projection_test.exs >"$inner" 2>&1
  code=$?
  rm -rf "$t"
  restore
  grep -E 'tests?, |Result:|validate_receipt.py' "$inner" | head -8
  echo "inner_exit=$code"
  [ "$code" = 2 ] && grep -Eq '8 tests, 5 failures|Result: 3/8 passed|5 failures|Failed: 5 tests' "$inner" || exit 90
  ;;
manifest-vsn1 | manifest-any)
  git show c68c74d:lib/xaas/ultracode/semantic_drive.ex >"$scratch/semantic_drive.c68c74d.ex"
  paths="$paths lib/xaas/ultracode/semantic_drive.ex"
  cp "$scratch/semantic_drive.c68c74d.ex" lib/xaas/ultracode/semantic_drive.ex
  if [ "$name" = manifest-vsn1 ]; then
    python3 - lib/xaas/ultracode/semantic_drive.ex <<'PY' || { restore; exit 91; }
import sys
p = sys.argv[1]; s = open(p).read()
o = '''  defp manifest_compiler(term) when is_tuple(term) and tuple_size(term) in [3, 4],
    do: elem(term, 1)
'''
n = '''  defp manifest_compiler({_vsn, compiler, _scm}), do: compiler
'''
assert s.count(o) == 1
open(p, "w").write(s.replace(o, n))
PY
  fi
  env PATH="$pin:$PATH" GGEN_IGNITER_DIR="$gi" mix test test/xaas/ultracode/semantic_drive_test.exs \
    --only module:Xaas.Ultracode.SemanticDriveToolchainTest >"$inner" 2>&1
  code=$?
  restore
  grep -E '^\s+[0-9]+\) test|Result:|tests?, ' "$inner"
  echo "inner_exit=$code"
  [ "$code" = 2 ] || exit 90
  if [ "$name" = manifest-vsn1 ]; then
    grep -q 'test a build compiled by this node.s Elixir on this ERTS resolves to that Elixir' "$inner" &&
      grep -q 'test both declared manifest shapes are read' "$inner" || exit 90
  else
    grep -q 'test an undeclared manifest shape is REFUSED(build_manifest_shape)' "$inner" || exit 90
  fi
  ;;
gi-mix)
  paths="$paths docs/sjira/v26.9.23/courts/gi_mix.sh"
  git show c68c74d:docs/sjira/v26.9.23/courts/gi_mix.sh >docs/sjira/v26.9.23/courts/gi_mix.sh
  env PATH="$pin:$PATH" XAAS_DIR="$wt" GGEN_IGNITER_DIR="$gi" MIX_ENV= \
    sh docs/sjira/v26.9.23/courts/GC23-0.sh >"$inner" 2>&1
  code=$?
  restore
  tail -3 "$inner" | cut -c1-240
  echo "inner_exit=$code"
  [ "$code" != 0 ] && ! grep -q '^ALIVE: GC23-0' "$inner" || exit 90
  ;;
court-policy)
  mutate test/sjira/v26_9_23_goal_test.exs <<'PY'
import sys
p = sys.argv[1]; s = open(p).read()
o = '''          "priv/no_llm/policy.json"
'''
assert s.count(o) == 1
s = s.replace(o, "")
s = s.replace('''          "scripts/sjira/prose_spans.py",
          # courts/no_llm_env.sh''', '''          "scripts/sjira/prose_spans.py"
          # courts/no_llm_env.sh''')
open(p, "w").write(s)
PY
  line0=$(grep -n 'test "GC23-0 (real sh + ggen_igniter compile_prose --check) refuses a hand-edited' test/sjira/v26_9_23_goal_test.exs | cut -d: -f1)
  line3=$(grep -n 'test "GC23-3 (real sh + ggen_igniter --admit-goal) refuses a goal.ttl' test/sjira/v26_9_23_goal_test.exs | cut -d: -f1)
  env PATH="$pin:$PATH" GGEN_IGNITER_DIR="$gi" mix test "test/sjira/v26_9_23_goal_test.exs:$line0" \
    "test/sjira/v26_9_23_goal_test.exs:$line3" >"$inner" 2>&1
  code=$?
  restore
  grep -E '^\s+[0-9]+\) test|no policy data|Result:|tests?, ' "$inner" | cut -c1-200
  echo "inner_exit=$code"
  [ "$code" = 2 ] && [ "$(grep -c 'no_llm_env: no policy data' "$inner")" -ge 2 ] || exit 90
  ;;
port-hash | port-held-committed)
  if [ "$name" = port-hash ]; then
    paths="$paths test/xaas/actuation_ocel_undo_test.exs"
    git show c68c74d:test/xaas/actuation_ocel_undo_test.exs >test/xaas/actuation_ocel_undo_test.exs
  fi
  # hold every port of the old hash range 42_777 .. 43_276 on 127.0.0.1
  python3 - "$scratch/ports.ready" <<'PY' &
import socket, sys, time
held = []
for port in range(42777, 43277):
    s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    try:
        s.bind(("127.0.0.1", port)); s.listen(1); held.append(s)
    except OSError:
        pass
open(sys.argv[1], "w").write(f"{len(held)}\n")
time.sleep(600)
PY
  holder=$!
  until [ -s "$scratch/ports.ready" ]; do sleep 1; done
  echo "held ports: $(cat "$scratch/ports.ready")"
  env PATH="$pin:$PATH" mix test test/xaas/actuation_ocel_undo_test.exs >"$inner" 2>&1
  code=$?
  kill "$holder" 2>/dev/null
  rm -f "$scratch/ports.ready"
  [ -n "$paths" ] && restore
  grep -E 'eaddrinuse|Result:|tests?, ' "$inner" | sort | uniq -c | head
  echo "inner_exit=$code"
  if [ "$name" = port-hash ]; then
    [ "$code" = 2 ] && grep -q eaddrinuse "$inner" || exit 90
  else
    [ "$code" = 0 ] || exit 90
  fi
  ;;
*)
  echo "unknown falsifier $name"
  exit 91
  ;;
esac
echo "FALSIFIER $name: fired as expected"
exit 0
