# W876 — Fanout rule lock (same-checkout-fanout.md additions)

- Date: 2026-10-07
- Subject: `/Users/sac/.claude/rules/same-checkout-fanout.md` — appended "Additions (2026-10-07, W876)" section (append-only, 3 rules, ~9 lines).
- O (wave receipts): w732/w762 lane incidents (shared-compile freezes from out-of-contract lib/ edits; stash collisions, memory already saved as `no-stash-baselining`), w672 finding (full-dir census exit-1 compile-abort indistinguishable from failures).
- Rules codified: (1) no `git stash` in shared checkouts — `git show HEAD:path` swap; (2) ~10-minute fix-or-revert SLA for shared `lib/` compile breaks, minimal cross-lane unblock fix allowed with receipt disclosure; (3) census tooling must separate compile-abort (exit 1, 0 tests) from test failures and name the broken file.
- Diff: hand-written, 1 file in ~/.claude config checkout; NOT committed (per lane instruction — config checkout, coordinator owns commits).
- Standing: observed (rule text on disk at the path above; no build root used, no xaas tree edits).
