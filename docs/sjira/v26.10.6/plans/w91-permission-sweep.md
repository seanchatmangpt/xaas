# W91 Permission Sweep Receipt — v26.10.6 Integration Lane

Date: 2026-10-06
Scope: 17 fleet repos under `/Users/sac/`, chmod-only (no content changes, no git).
Damage class: directories missing owner `x` (non-traversable), files missing owner `r`.
Repair: `chmod -R u+rwX` on damaged repos only. `u+rwX` adds owner X only where
already a dir or already exec — no new exec bits on regular files.

## Sweep (find ! -perm -u+x on dirs; ! -perm -u+r/-u+w on files)

| repo | dirs missing u+x (pre) | files missing u+r/u+w (pre) | action |
|---|---|---|---|
| xaas | 0 | 4377 (all `.git/objects` + `deps/` 444 — by design, not damage) | none |
| ash_surface | 58 (node_modules/zod subtree) | 219 | REPAIRED |
| ggen | 0 | 2071 (`.git`/`deps` 444 — normal) | none |
| ggen-marketplace | 0 | 2739 (normal 444) | none |
| ggen_igniter | 81 (priv/** subtree) | 990 | REPAIRED |
| ash_a2a | 0 | 2927 (normal 444) | none |
| ash_pplan | 0 | 4424 (normal 444) | none |
| ferroplan | 0 | 4375 (normal 444) | none |
| zcode-cli | 0 | 498 (normal 444) | none |
| gymact | 0 | 2150 (normal 444) | none |
| beam4pm | 3 (priv, priv/bin, priv/prior_art) | 9559 | REPAIRED |
| wasm4pm | 0 | 2864 (normal 444) | none |
| autofde-lab | 0 | 0 | none — clean |
| ash_affidavit | 0 (priv is drwx------ — owner rwx present, traversable for owner; group/other stripped only) | 3748 (normal 444) | none |
| ash_graphlaw | 4 (priv + priv/{plts,prior_art,graphlaw}) | 1065 | REPAIRED |
| ex4pm | 0 | 4227 (normal 444) | none |
| ash_r2rml | 0 | 0 | none — clean |

## Repaired counts (before → after)

| repo | dirs missing u+x | files missing u+r |
|---|---|---|
| ash_surface | 58 → 0 | 0 → 0 |
| ggen_igniter | 81 → 0 | 0 → 0 |
| beam4pm | 3 → 0 | 0 → 0 |
| ash_graphlaw | 4 → 0 | 0 → 0 |

Full-tree recount after repair: 0 dirs missing u+x and 0 files missing u+r in
all 17 repos. Owner-unwritable files remaining are exclusively `.git/objects`
(git sets 0444 by design) and `deps/` hex packages (hex sets 0444 by design) —
left untouched per scope.

## Notes

- `~/ash_affidavit/priv` observed as `drwx------` (matches the reported damage
  class appearance) but retains owner rwx — traversable for the owner. Not in
  repair scope; group/other bits stripped only.
- The `priv/` loss pattern (ggen_igniter, beam4pm, ash_graphlaw, and
  ash_affidavit group/other stripping) is consistent with a `chmod -R` run
  from a restrictive umask targeting priv subtrees; root cause not determined
  in this sweep (chmod-only lane).
- Commands: `find <repo> -type d ! -perm -u+x`, `find <repo> -type f ! -perm -u+r -o ! -perm -u+w`,
  `chmod -R u+rwX <repo>`. All exits 0.
