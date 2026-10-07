# S3 Evidence Pack Replay Validation — Lane W439 (v26.10.6)

Subject: /Users/sac/xaas @ feat/playwright-surface, HEAD `d1db2b03179975213c14663b9dbd86b5ac2a14cf`
Validated: docs/cro/artifacts/s3-evidence-pack-v26.10.6.md §3 (non-mix items only).

## Per-command receipts

### 3.3a Subject binding — EXECUTES-AS-DOCUMENTED

```
$ git -C /Users/sac/xaas rev-parse HEAD
d1db2b03179975213c14663b9dbd86b5ac2a14cf
```
Ledger `head_sha` field (found by recursive walk of
`docs/cro/artifacts/refusal-ledger-v26.10.6.jcs.json`): `d1db2b03179975213c14663b9dbd86b5ac2a14cf`.
Match. HEAD sha unchanged (no commits made during campaign lanes); tree file
content has moved past d1db2b03 via uncommitted lane edits, which the sha
binding does not claim to cover.

### 3.3b w202 comm recount — EXECUTES-AS-DOCUMENTED

```
$ comm -23 \
    <(grep -rhoE 'REFUSED_[A-Z_]+' /Users/sac/xaas/lib/ | sort -u) \
    <(grep -rhoE 'REFUSED_[A-Z_]+' /Users/sac/xaas/test/ | sort -u)
(empty output, exit 0)
```
Expected empty (delta 0) — confirmed.

### 3.3c Ledger canonical round-trip — EXECUTES-AS-DOCUMENTED

```
$ python3 -c '...jcs.json... assert s==json.dumps(json.loads(s),...)'
ROUNDTRIP_OK (exit 0)
```
Parse + canonical serialization is stable and byte-identical.

### Ledger file sha256 — FINDING (stale integrity sha)

```
$ shasum -a 256 docs/cro/artifacts/refusal-ledger-v26.10.6.jcs.json
4625e610cd80062722acea5dbd27c7ea1a7242b57f6a994cd1bd018232dd5117  docs/cro/artifacts/refusal-ledger-v26.10.6.jcs.json
```
The canonical form hashes to the same value (file is already canonical).

`docs/cro/artifacts/artifact-integrity.md:40` records the canonical-form sha as
`2060f0f8ad580fbe8ba76c7c5c9d4a86d6648e1aa8683a26b119fcb5d29ef3c1` (marked
STABLE). The ledger changed after the w382/w414 updates; current sha is
`4625e610cd80062722acea5dbd27c7ea1a7242b57f6a994cd1bd018232dd5117`.
The old sha no longer matches: stale integrity record, reported (artifact is
w426's; not fixed here).

## Not run (out of lane scope)

- §3.1 refusal corpus 12-file mix test — VERIFIED-BY-W398-PENDING.
- §3.2 ash_a2a conformance court — VERIFIED-BY-W398-PENDING (also outside
  this repo/checkout).

## Verdict summary

| Command | Verdict |
|---|---|
| git rev-parse HEAD vs ledger head_sha | EXECUTES-AS-DOCUMENTED |
| w202 comm recount (lib vs test REFUSED_ tokens) | EXECUTES-AS-DOCUMENTED (empty, delta 0) |
| JCS canonical round-trip | EXECUTES-AS-DOCUMENTED |
| Ledger sha vs artifact-integrity.md | FINDING: stale sha in integrity doc (2060f0f8… vs actual 4625e610…) |
| §3.1 mix corpus | VERIFIED-BY-W398-PENDING |
| §3.2 conformance court | VERIFIED-BY-W398-PENDING |

Broken count: 1 (the stale integrity sha, a documentation drift finding, not a
broken replay command). All executable non-mix replay commands execute as
documented.
