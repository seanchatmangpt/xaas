# W896 — release_audit enoent court: ownership receipt

> **ADDENDUM (2026-10-07, post-write): superseded in the owner slot.**
> `plans/w873-enoent-court.md` landed after this note was written and NAMES
> `test/xaas/release_audit_enoent_court_test.exs` (4 passed solo, 8 passed
> jointly with `xaas_release_audit_test.exs`, standing ALIVE — verified on
> disk by W896). The manifest row flips IN_FLIGHT → COMMIT with
> **w873-enoent-court.md as the owner receipt**; no coordinator admission
> needed. This note's "w873 receipt absent" premise was true at write time
> and is now historical; the ownership evidence and dispatch match below
> stand as independent confirmation. W896b is fixing the two court-shape
> defects (wrapped-refusal matching + OS-19 `@version` scan exception);
> expect 4/4 after W896b lands. This file remains as the hardening record.

Lane: W896, xaas v26.10.6, canonical checkout `/Users/sac/xaas`
(branch `feat/playwright-surface`, uncommitted worktree state per wave). Date: 2026-10-07.
Trigger: W889b finding that `test/xaas/release_audit_enoent_court_test.exs` was
IN_FLIGHT / UNCLAIMED — no landed receipt names it.

## Ownership evidence

**Re-check for a late-landing w873 receipt (2026-10-07, this lane):**

```
$ ls docs/sjira/v26.10.6/plans/ | grep -iE 'w873'
(no matches)
$ grep -rl w873 docs/sjira/v26.10.6/
COMMIT manifest row + w889b-addendum-receipt.md + w889b-manifest-addendum.md
(lease/status traces only — no plans/w873-*.md receipt exists)
```

A `w873-*.md` receipt still does NOT exist. **Minting this note as the
ownership record** per dispatch option (b).

**Dispatch match — file content vs W873's dispatch.** The file self-identifies
as W873's mint in three independent places:

- moduledoc line 3: "W873 regression court for the release_audit typed-absent
  behavior (W845/W872 hardening)"
- fixture paths: `probe_dir()` → `_build-laneW873/enoent_probe`;
  `fixture_repo()` → `xaas-w873-enoent-fixture` (lines 129–135)

Coverage matches the W873 dispatch exactly:

| Dispatch requirement | Court in file |
|---|---|
| W872 required-input refusal (`VERSION` absent → loud typed `REFUSED(release_audit, … :enoent)` Mix.Error, never `File.Error`) | test at line 43 |
| `check_stale_claims` / `check_json` / `check_markdown_links` typed-absent arms (W845 class) | test at line 82 (tracked-but-absent json/md → typed `:enoent` findings, findings-count refusal, no crash) + determinism test at line 115 |

Conclusion: **minted by lane W873** (provenance: internal W873 identifiers in
the file itself; no other lane's identifiers appear). Ownership assigned to
W873 retroactively; this receipt is the ownership record.

## Verification (real run, pinned toolchain)

`PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test mix test test/xaas/release_audit_enoent_court_test.exs`

**Result: 2/4 passed, 2 failed.**

- PASS: "W872: VERSION absent in cwd is a loud typed refusal, not a File.Error"
- PASS: "determinism: the typed-absent refusal set is identical across two runs"
- FAIL: "W845: tracked-but-absent json/md/text files yield typed :enoent findings" —
  expected bare finding strings (`"tracked JSON file absent in worktree: absent.json"`)
  but `capture_refusal_lines` returns full `REFUSED(release_audit, detail: %{finding: "…"})`
  lines; the substring comparison is a bare-vs-wrapped shape mismatch (all five
  expected findings ARE present, wrapped). Test-shape defect, not a lib defect —
  the typed-absent behavior itself is observed working in the same output.
- FAIL: "W872: every required input path takes the same typed-absent refusal arm" —
  source-shape scan flags `File.read!("VERSION"` outside `required_input!/1`
  (the OS-19/W700 `@version File.read!("VERSION")` line at
  `lib/mix/tasks/xaas.release_audit.ex:14`, which predates W872). Court is
  stricter than the landed OS-19 fix; assertion scope defect.

Both failures are court defects (assertion shape / over-broad source scan), not
evidence against the W845/W872 hardening; the hardening is observed working in
the failing tests' own captured output.

## Manifest proposal

Row 5 of `_COMMIT_MANIFEST_W850.md` (`test/xaas/release_audit_enoent_court_test.exs`,
currently **IN_FLIGHT / UNCLAIMED**):

- Flip to: **COMMIT, CG-14-adjacent (own row)**, owner
  `plans/w896-enoent-court-owner.md` (this file, retroactive W873 provenance).
- Condition: land with the two court-shape defects disclosed (2/4 currently
  green; the two failures are assertion-shape defects in the court itself,
  typed-absent behavior observed working). Repair is a v26.10.7 one-liner
  class: compare wrapped REFUSED lines (or capture findings before wrapping),
  and exempt the OS-19 `@version` read site in the source-shape scan.
- Standing: PARTIAL_ALIVE (courts execute; 2 assertion defects open).
