# W628b — ash_a2a doc-coherence fix (v26.10.7 seal, deterministic failures 1+2)

Standing: ALIVE (observed execution on exact subject)

## Subject
- Repo: `~/ash_a2a`, branch `feat/tck-vuln-hardening`
- Base: `e0fb769e` (tag `v26.10.7`)
- Head: `13dd1a57` — `docs(reference): W628b sync a2a-spec-version-mapping Version line to v26.10.7`
- Pushed fast-forward to `origin/feat/tck-vuln-hardening` (e0fb769e..13dd1a57). No force.

## Change (μ/diff)
- `docs/reference/a2a-spec-version-mapping.md:9`: `Version: v26.10.5` → `Version: v26.10.7`.
- Only the release-version reference changed. Historical mapping rows and the
  SA2A profile constants (`SA2A-PROFILE-v26.9.20`, `SA2A-STRICT-v26.9.20`,
  protocolVersion `1.0`) are untouched — those name the profile revision /
  wire protocol, not the package version (per the doc's own note, lines 27-30).
- Generated vs handwritten: handwritten doc edit (irreducible residue; the doc
  itself declares it test-driven, not generated).

## Verification (commands/exits)
```
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test mix test \
  test/supply_chain/release_path_test.exs \
  test/ash_a2a/a2a_transport/spec_mapping_doc_test.exs
...
Finished in 1.1 seconds (1.1s async, 0.00s sync)
Result: 3 passed
```
- `SupplyChain.ReleasePathTest` version-coherence test: green.
- `A2ATransport.SpecMappingDocTest` Version-line doctest: green.
- Both formerly-failing tests (W628 deterministic failures 1+2) now pass.

## Tag semantics (coordinator decision note)
Tag `v26.10.7` remains at `e0fb769e`. Recommendation: ride the fix post-tag on
`feat/tck-vuln-hardening` — the tag froze the release content, and doc-coherence
fixes are post-release corrections. Do NOT re-point the tag (no force-move; the
tagged tree is the honest record of what shipped). If the coordinator prefers the
doc inside the tagged content, that is an explicit tag re-point decision outside
this lane's authority.

## Third deterministic failure
Architecture verifier 300s timeout: pre-existing environment, untouched per
assignment.

## Transport failures
None. Push succeeded fast-forward.

## Untracked residue (pre-existing, not this lane's)
`docs/thesis/`, `test/ash_a2a/w608_map_update_court_test.exs` — left alone.
