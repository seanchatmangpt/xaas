# W650h31 — ash-pplan-dsl-pack ontology mirror sync

Lane W650h31, v26.10.7 fleet seal. Fixes the pre-existing drift W650j
disclosed in `w650j-pplan-pins.md`: `priv/ggen/ash-pplan-dsl-pack/ontology.ttl`
in `~/ash_pplan` was stale at 26.10.3 while root `ontology.ttl` is 26.10.7.
Note: the dsl-pack mirror lives in `~/ash_pplan` (not `~/xaas`); the court
files are ash_pplan's.

## Edit (1 file)

`priv/ggen/ash-pplan-dsl-pack/ontology.ttl` — rebuilt as the exact 4-line
GENERATED-PROVENANCE header (3 comment lines + blank) + byte-identical copy
of repo-root `ontology.ttl`, same construction W650j used for the two
landed mirrors.

## Digests

- before: `b63fa769911d0aec9eee6f32fb8d2ad6f1de6e41cfec0173a31d6dd48818ac23` (stale 26.10.3 body)
- after:  `94563b6775bb748e531bf694985d002fa66fdfedcf4979d7d00fd442588f86d1`
- root `ontology.ttl`: `2d4c382dd023c397c28de9982e0a497e1abbfdaa0fd287216758b2f094ab5e84`
- siblings `ash-pplan-pack` / `ash-pplan-workflow-pack` mirrors: `94563b67…` —
  dsl-pack mirror now **byte-identical** to both landed siblings (diff clean);
  body diff vs root clean; `owl:versionInfo "26.10.7"` at line 21.

## Court

```
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW650h31 \
  mix test test/ash_pplan_test.exs test/release_contract_test.exs
42 passed, 0 failures (fresh _build-laneW650h31 root, deleted after run)
```

Pack-identity court (header + byte-identity vs root) green on the synced
mirror set; version-pin courts green at 26.10.7.

## Standing

ALIVE — exact subject `847f487` (ash_pplan main/fix branch tip, uncommitted
working-tree edit on top), court witnessed above. DO NOT commit (lane
constraint); the edit is left in `~/ash_pplan` working tree for coordinator
integration. Handwritten mirror construction (header+body rebuild, no
generator in this repo's loop for this file).
