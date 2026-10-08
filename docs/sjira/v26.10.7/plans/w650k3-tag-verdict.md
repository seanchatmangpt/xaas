# W650k3 — Tag-vs-HEAD Verdict (v26.10.7 Fleet Seal)

Lane: W650k3, verify-only, git read-only + ls-remote. Subject: /Users/sac/xaas @
local HEAD `1b14ec1e` (branch `feat/playwright-surface`). Observed 2026-10-07.

Note: task brief named HEAD `c6a750bb`+; actual local HEAD at observation time is
`1b14ec1e` (2 newer receipt commits: 795ba02e, 1b14ec1e). Ancestry findings below
are against `1b14ec1e`.

## (1) xaas tag peel

- `git rev-parse v26.10.7^{commit}` → `56325fa529927d317d551da4dd62e436296edf06`
  (annotated tag object `ccad2a59`; tag = version-bump seal commit
  "chore(release): v26.10.7 version bump seal", 2026-10-07).
- Matches W649's recorded value — the tag has **not** moved. W650k2's "zero
  findings" is the fixed tag-check passing against this same commit.
- `git merge-base --is-ancestor 56325fa5 HEAD` → YES. `rev-list 56325fa5..HEAD`
  count = **42**.
- Post-tag commits include real non-doc subjects: `428ae270` (W650k2 audit
  remediation), `5997a4a9` (graphlaw courts), `bae6bdc1` (7 depth-court tests),
  `ea886c6a` (36 owner-complete test files). The audited working tree ≠ the
  tagged subject.

## (2) Seal-truth verdict for xaas

**Tag re-point is NOT required.** The W628b convention (tag freezes release
content; post-tag fixes ride the branch) applies: every post-tag commit is an
ancestor-descendant of the tag and the release surface (VERSION 26.10.7, audit
constants) is intact at HEAD. Repointing a pushed tag (delete + force-push)
would violate immutability discipline for no truth gain.

Disclosure required, not re-point: `mix xaas.release_audit` exit 0 / zero
findings ran against the **working tree at HEAD**, not the tagged subject. The
seal claim must be worded "v26.10.7 tagged at 56325fa5; audit-green at HEAD
(42 commits ahead, remediation rides the branch)" — not "audit-green at tag".

**Transport finding (new, honest):** `56325fa5` is **not** an ancestor of
`origin/main` (`refs/heads/main` = `5fc56da2`, which is *behind* the tag —
`rev-list 56325fa5..origin/main` = 0). The tag is pushed to origin
(ls-remote confirms object + peel) but the commit is reachable only from
`feat/playwright-surface`. The seal currently freezes a subject that main does
not contain. Merging the branch to main is a coordinator transition (not this
lane's, verify-only); without it the seal is branch-local.

## (3) 8-repo tag-vs-HEAD table

| repo | tag peel `v26.10.7^{}` | local HEAD | ancestor | ahead | remote main | tag reachable from remote main? |
|---|---|---|---|---|---|---|
| xaas | `56325fa5` | `1b14ec1e` | YES | 42 | `5fc56da2` | NO (main behind tag; commit branch-only) |
| ash_a2a | `e0fb769e` | `13dd1a57` | YES | 1 (docs W628b mapping sync) | `86214551` | (not checked; 1 doc-only) |
| ggen | `905d8af3` | `905d8af3` | YES | 0 | `d593a7f3` | n/a (tag==HEAD) |
| ggen_igniter | `c3cd5d2b` | `c3cd5d2b` | YES | 0 | `90a5c63a` | n/a (tag==HEAD) |
| wasm4pm | `986e5daa` | `986e5daa` | YES | 0 | `a7352d81` | n/a (tag==HEAD) |
| ash_graphlaw | `3ecae0e7` | `3ecae0e7` | YES | 0 | `3ecae0e7` | YES (main == tag) |
| ash_pplan | `862f0c0b` | `847f487b` | YES | 2 (`110f5d6` gitignore, `847f487b` W650j version-companion fix) | `847f487b` | main == HEAD, tag behind main by 2 |
| gymact | `8472ffd2` | `8472ffd2` | YES | 0 | `c62c26ac` | n/a (tag==HEAD) |

All 8 tags are annotated and peel to an ancestor of the local HEAD. Three repos
carry post-tag commits: xaas (42, incl. audit remediation), ash_pplan (2, incl.
`847f487b` version-companion fix — arguably release content), ash_a2a (1,
docs-only).

## Standing

- **Verdict: PARTIAL_ALIVE (truthful with disclosures; no re-point required).**
  - Tag freeze convention W628b applies: post-tag fixes ride the branch →
    tag re-point/force-push NOT required for seal truth.
  - Disclosure 1: audit zero-findings is HEAD-subject, not tag-subject.
  - Disclosure 2 (BLOCKED-class for coordinator): xaas seal commit not reachable
    from origin/main — main is *behind* the tag. Seal is branch-local until
    merge.
  - Optional coordinator item: ash_pplan `847f487b` (version companions) is a
    post-tag fix of release content; whether to cut v26.10.8 or accept per
    W628b is an operator decision, not this lane's.

## Commands / replay

```
git rev-parse 'v26.10.7^{commit}' HEAD; git merge-base --is-ancestor …HEAD
git log --oneline <tag>..HEAD | wc -l
git ls-remote origin refs/tags/v26.10.7 'refs/tags/v26.10.7^{}' refs/heads/main  # x8 repos
git merge-base --is-ancestor 56325fa5 origin/main   # NO (xaas)
```

All exits 0 except the two recorded NO ancestry results (informational). No
commits, no tag mutations, no working-tree changes made by this lane.
