# W982h — vendored ggen-marketplace pin-drift investigation (beam4pm submodule)

Lane: W982h (xaas v26.10.6 campaign). Read-only in sibling repos; only writes were
the ledger row correction (`docs/cro/artifacts/airo-wiring-ledger.md`,
beam4pm/vendor/ggen-marketplace row + gitlink note) and this receipt.
Follows W981w's court finding: exactly 1 DRIFT — recorded `6e4de9765` not an
ancestor of submodule HEAD `6e9344140`.

## 1. Object existence + merge-base analysis

In `/Users/sac/beam4pm/vendor/ggen-marketplace`:

```
git cat-file -t 6e4de9765 → commit
git cat-file -t 6e9344140 → commit
git merge-base 6e4de9765 6e9344140 → fd85ff2404cb1c71b2a05784674db5beed00f2ec
```

- `fd85ff240` = "release: bump marketplace version to v26.10.1" (2026-10-01) and is
  the **parent of `6e4de9765`** — so `6e4de9765` sits on the pre-rebase lineage.
- `6e9344140`'s parent is `3ddbfeb7e` (2026-10-05, remote head at rebase time);
  `git rev-list fd85ff240..6e9344140 | wc -l` → 57 commits (56 remote + the rebased W658b).
- Subject, author, and author date (2026-10-07 06:38:03 -0700) of both commits are
  identical: "chore(vendor-pack): beam4pm-process-model-pack debt ceiling 99→102 (W658b)".

Cause: W980b's NON_FAST_FORWARD push repair rebased the single disjoint W658b commit
onto origin/main (`6e4de9765` → `6e9344140`), per
`docs/sjira/v26.10.6/plans/w980b-submodule-push.md` §2 (zero overlap with the 56
remote commits; `--autostash`, remote untouched during rebase).

## 2. Content equivalence (disposition evidence)

```
git show 6e4de9765 | git patch-id --stable → 7488b9e3cfd6be217d3d4d937a2550bc23597aa5
git show 6e9344140 | git patch-id --stable → 7488b9e3cfd6be217d3d4d937a2550bc23597aa5
→ PATCH_IDS_EQUAL
```

Both patches touch exactly `packs/beam4pm-process-model-pack/ontology.ttl` with the
same blob transition `d12207ff9..29e301ab4` (ceiling 54→102 within the same hunks,
identical W658b rationale text — visually diffed in full). Nothing from `6e4de9765`
is absent from `6e9344140`: the tree delta between the two commits
(400 files, +29864/−614) is entirely the 56 upstream commits the rebase brought in
— strictly newer content, no lost content.

## 3. Disposition: (a) content-equivalent → ledger row updated

Ledger row now records `6e93441406684f6270a90c7f44660cbadbe0500d`, citing w980b
(rebase) + w982h (equivalence). Also updated the ledger's gitlink note:

```
git -C ~/beam4pm rev-parse HEAD:vendor/ggen-marketplace
→ 6e93441406684f6270a90c7f44660cbadbe0500d  (= submodule HEAD; gitlink already
   committed in beam4pm HEAD 7312ffcd4, not dangling)
```

## 4. Court rerun (real tails, after the ledger edit)

```
$ PATH=$HOME/.asdf/shims:$PATH elixir docs/airo/pin_drift_check.exs
before: {current: 19, ancestor: 1, drift: 1, missing: 0}
after:  {current: 20, ancestor: 1, drift: 0, missing: 0}
```

Remaining non-CURRENT row is `beam4pm` = ANCESTOR (recorded pin is an ancestor of
HEAD — fast-forwarded, lawful). Expected drift: 0 — matched.

## Standing

- ALIVE (exact subject: ledger edit + court rerun on disk). Submodule SHAs verified
  read-only in `~/beam4pm/vendor/ggen-marketplace`; no sibling repo mutated.
- drift 0 / missing 0 across all 22 ledger rows.
- Falsifier: had patch-ids differed, disposition would have been (b) BLOCKED with a
  named lost-content finding; had `6e4de9765` failed `git cat-file -t`, (c)
  REFUSED(unverifiable). Neither fired.
