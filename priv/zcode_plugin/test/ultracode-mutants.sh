#!/bin/sh
# Mutation falsifier for scripts/ultracode-run.mjs (XAAS-26922-26 rt-A): exit 0 iff every
# mutant of the committed projection is killed by `selftest`. Run from the repo root.
# Mutants run concurrently; each selftest works in its own mkdtemp root with a fake HOME.
SRC=priv/zcode_plugin/marketplace/xaas-fabric/scripts/ultracode-run.mjs
D=$(mktemp -d)
export ULTRACODE_SELFTEST_AGENT="$PWD/priv/zcode_plugin/test/ultracode-scripted-agent.mjs"
sed 's/if (active < n) { active++; return; }/{ active++; return; }/' $SRC > $D/semaphore-cap-ignored.mjs
sed 's/(src.byLabel.get(label) || \[\])\[labelIndex\]/(src.byLabel.get(label) || [])[labelIndex + 1]/' $SRC > $D/label-off-by-one.mjs
sed 's/cwd, resume: sid })/cwd })/' $SRC > $D/reask-without-resume.mjs
sed 's/const errs = preflightSchema(opts.schema);/const errs = [];/' $SRC > $D/no-schema-preflight.mjs
sed 's/if (c.opts.agentType === "Explore") {/if (false) {/' $SRC > $D/no-explore-readonly.mjs
sed 's/if (scan.code\[m.index\] === 1) {/if (false) {/' $SRC > $D/no-nondeterminism-check.mjs
sed 's/const statics = staticScan(src, scan, file, aliases);/const statics = { schemas: [], workflowRefs: [] };/' $SRC > $D/no-static-schema-scan.mjs
sed 's/^  staticChildren(loaded, cwd);$/  void 0;/' $SRC > $D/no-static-children.mjs
sed 's/Math.max(Number.isInteger(s.minItems) ? s.minItems : 0, 1)/(Number.isInteger(s.minItems) ? s.minItems : 0)/' $SRC > $D/probe-empty-arrays.mjs
sed 's/env("ULTRACODE_RERUN_NULL", "") !== "1"/env("ULTRACODE_RERUN_NULL", "") === "1"/' $SRC > $D/rerun-null-by-default.mjs
sed 's/"It failed schema validation:",/"(previous attempt rejected)",/' $SRC > $D/fresh-reask-drops-errors.mjs
sed 's/^const ultracodeHome = () => env("ULTRACODE_HOME", path.join(os.homedir(), ".zcode", "ultracode"));$/const ultracodeHome = () => path.join(os.homedir(), ".zcode", "ultracode");/' $SRC > $D/ignore-ultracode-home.mjs
sed 's/const e = intEnv("ULTRACODE_CONCURRENCY", 0);/const e = 0;/' $SRC > $D/ignore-concurrency-env.mjs
sed 's/for (let k = 2; fs.existsSync(path.join(root, s)) || git(/for (let k = 2; false \&\& git(/' $SRC > $D/worktree-name-collision.mjs
rc=0
for m in $D/*.mjs; do
  if cmp -s $SRC $m; then echo "NOT-APPLIED $(basename $m)" > $m.verdict; rc=1; continue; fi
  ( out=$(node $m selftest 2>&1); code=$?
    if [ $code -ne 0 ]; then echo "KILLED $(basename $m): $(echo "$out" | grep -m1 '^FAIL' | cut -c1-110)"; else echo "SURVIVED $(basename $m)"; fi > $m.verdict ) &
done
wait
cat $D/*.verdict
grep -q '^\(SURVIVED\|NOT-APPLIED\)' $D/*.verdict && rc=1
echo "mutants: $(grep -c '^KILLED' $D/*.verdict | awk -F: '{s+=$2} END {print s}') killed of $(ls $D/*.mjs | wc -l | tr -d ' ')"
rm -rf $D
exit $rc
