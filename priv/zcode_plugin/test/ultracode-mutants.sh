#!/bin/sh
# Mutation falsifier for scripts/ultracode-run.mjs (XAAS-26922-26 rt-A): exit 0 iff every
# mutant of the committed projection is killed by `selftest`. Run from the repo root.
SRC=priv/zcode_plugin/marketplace/xaas-fabric/scripts/ultracode-run.mjs
D=$(mktemp -d)
export ULTRACODE_SELFTEST_AGENT="$PWD/priv/zcode_plugin/test/ultracode-scripted-agent.mjs"
sed 's/if (active < n) { active++; return; }/{ active++; return; }/' $SRC > $D/semaphore-cap-ignored.mjs
sed 's/(src.byLabel.get(label) || \[\])\[labelIndex\]/(src.byLabel.get(label) || [])[labelIndex + 1]/' $SRC > $D/label-off-by-one.mjs
sed 's/cwd, resume: sid })/cwd })/' $SRC > $D/reask-without-resume.mjs
sed 's/const errs = preflightSchema(opts.schema);/const errs = [];/' $SRC > $D/no-schema-preflight.mjs
sed 's/if (c.opts.agentType === "Explore") {/if (false) {/' $SRC > $D/no-explore-readonly.mjs
sed 's/if (scan.code\[m.index\] === 1) {/if (false) {/' $SRC > $D/no-nondeterminism-check.mjs
rc=0
for m in $D/*.mjs; do
  if cmp -s $SRC $m; then echo "NOT-APPLIED $(basename $m)"; rc=1; continue; fi
  out=$(node $m selftest 2>&1); code=$?
  if [ $code -ne 0 ]; then echo "KILLED $(basename $m): $(echo "$out" | grep -m1 '^FAIL' | cut -c1-110)"; else echo "SURVIVED $(basename $m)"; rc=1; fi
done
rm -rf $D
exit $rc
