# Vector 6 — Documentation, ABI Registries & Contract Reconciliation (v26.10.6)

Repos: `/Users/sac/xaas` (HEAD `d1db2b03179975213c14663b9dbd86b5ac2a14cf`, branch
`feat/playwright-surface`) and `/Users/sac/ash_surface` (HEAD `db5a889`). Read-only
audit; hashes recomputed with `shasum -a 256` / `hashlib.sha256`, no builds, no tree
mutations.

## 1. Registry drift (recomputed sha256 vs recorded digests)

### ash_surface conformance corpus — NO DRIFT

`/Users/sac/ash_surface/conformance/MANIFEST.json` (lawVersion 26.10.1, 547 vectors,
11 files). All 11 vector files re-hashed; every recorded sha256 and vectorCount matches:

| vector file | recorded sha256 | recomputed | vectorCount |
|---|---|---|---|
| vectors/transport_selection.json | `8b43af8be045ea0e…` | match | 381 / 381 |
| vectors/transport_facts_admission.json | `8ad005e51302584a…` | match | 12 / 12 |
| vectors/canonical_json.json | `c12e3cddfb230d4d…` | match | 26 / 26 |
| vectors/surface_contract_digest.json | `e6b02517a854173f…` | match | 10 / 10 |
| vectors/surface_contract_refusal.json | `0d5c08dd77ea3170…` | match | 8 / 8 |
| vectors/receipt_digest.json | `c1a745af1a33123f…` | match | 5 / 5 |
| vectors/receipt_binding.json | `273dcad3613f77e7…` | match | 31 / 31 |
| vectors/refusal_vocabulary.json | `f5639049c214e5d8…` | match | 30 / 30 |
| vectors/reconcile_status.json | `b225cea2d8e62856…` | match | 16 / 16 |
| vectors/ir_codec.json | `4a9792147b71feac…` | match | 19 / 19 |
| vectors/transport_outcome.json | `b8bc72adcb13b8090…` | match | 9 / 9 |

`lawVersion: "26.10.1"` equals `mix.exs:4 @version "26.10.1"` — consistent.

### xaas machine registries — NO RECORDED DIGEST TO VERIFY (gap, not mismatch)

No published digest anywhere in either repo covers these in-repo registries; hashes
below are the audited baselines (v26.10.6 can adopt them or add a manifest):

| registry | sha256 (recomputed) | verifiability |
|---|---|---|
| `xaas:priv/ash_surface/surface_contract.json` | `cba66d0be831d4ea2b4760839d0a45f1e850b3626e5cb37c2c436187998b8846` | no recorded digest in either repo |
| `xaas:priv/ash_surface/live_view.json` | `1ed405000fc968550915fe16a16f685153be9f6ea5876412f01d0b380d4a2816` | no recorded digest |
| `xaas:priv/ash_surface/aria.json` | `4ea01bc473c1784223acb4e2a1fc30625f95f830d1543888ffc41d400744ce8e` | no recorded digest |
| `xaas:priv/ultracode/runtime_surface.json` | `985a8ca025a832857aca087128d298ece67edee88c7e46c63d3bacdc92c2bef4` | no recorded digest (doc only names the path) |
| `xaas:priv/ultracode/remote-relay.contract.json` | `76ff551c16cea5afb40b385ecee9ab7462ce1d73bee47655c0e0c63dc0a33f89` | no recorded digest |
| `ash_surface:tmp/tdb-surface/render_digest.txt` | `c9f996bb1e796c477a92f0ac10b48b27ddc799bd59d9c08a4f7f5597fdf4bbea` | tmp/ artifact, non-authoritative |

Version skew (soft drift): `surface_contract.json:1` declares
`"generatorIdentity":"ash_surface:v26.10.1"` while ash_surface HEAD (`db5a889`, EA127
burn-in + namespace_prefix projectors) is past 26.10.1 — the copies may predate the
new projector features; not verifiable read-only without a build. Flag for
regeneration under v26.10.6.

## 2. Docs vs surface gaps

| # | doc claim (file:line) | code reality | severity |
|---|---|---|---|
| D1 | `docs/claude/diataxis/reference/http-api-surface.md:3-8,115-118` — "62 resources declare `base(...)`: 56 `/api`, 1 `/internal-api`, 5 Library", verified 2026-09-22 | `grep -rl 'base("/' lib/xaas` = **70 files** (2026-10-06). +8 undocumented resources incl. the whole `approval_*` / `castle_verb_*` / `route_*` family | high |
| D2 | `http-api-surface.md:14-18,598` — browser surface enumerated as `/`, `/next-read`, 3 WdFa routes | `lib/xaas_web/router.ex:64` adds `live("/marketplace-catalog", MarketplaceCatalogLive)` — absent from doc (and its PW3 Playwright E2E) | medium |
| D3 | `docs/claude/diataxis/reference/ash-configuration.md:14,58-62` — "13 domains (`config.exs:13-27`)" | `config/config.exs:13-33` now configures **19 domains** (added `Xaas.A2a`, `Xaas.Conference`, `Xaas.Graphlaw`, `Xaas.Igniter`, `Xaas.Security`, `Xaas.Witness`) | high |
| D4 | `README.md:7` — "Thirteen Ash domains are configured…" | same as D3: 19 | high |
| D5 | `README.md:9-11` — capability snapshot "observed … on `main@c2a7ea9fbefc9e45d89c30fad36afb3fee96fabd`" | `main` is now `5fc56da2` (v26.10.1-loop merge); snapshot pin stale, no v26.10.x snapshot exists | medium |
| D6 | `CHANGELOG.md` (xaas) — highest entry `[v26.9.28]`; file dated 2026-09-26 | `VERSION` = `26.10.2`; `docs/sjira/v26.10.{1,3,5,6}` work streams have no changelog entries | medium |
| D7 | `Xaas.Witness` domain (PW5, commit `3508f427`): `lib/xaas/witness.ex`, `witness/catalog.ex`, `witness/certified_receipt.ex`, `witness/verification_key.ex` | **zero** authoritative docs coverage (no diataxis page; only sjira plans mention it); no router entry either — domain exists in `ash_domains` but is closed to HTTP | medium (docs) / by-design (routes) |
| D8 | `/api` mounts 7 domains (`api_router.ex:13-19`) — doc correct | still 7; but 12 of 19 domains are now unmounted (doc says 6 of 13) — consequence of D3 | low |
| D9 | ash_surface `CHANGELOG.md` `[Unreleased]` empty | 5+ commits after `26.10.1` (db5a889 EA127, 2da7b83 digest extraction, bbd5a56/79b4ef8 namespace_prefix) unrecorded | low |

No reverse gaps found in the checked sample: every documented Mix task in
`README.md`/`ultracode-runtime-contract.md` resolves to a real file under
`lib/mix/tasks/` (51 tasks), and the 11 Mix tasks named in `ultracode-runtime-contract.md:120-139`
witness table all exist as test files. `RuntimeSurface.admit_declaration/1`
(`lib/xaas/ultracode/runtime_surface.ex:162-164`) exists as documented.

## 3. Stale-doc elimination list for v26.10.6

| # | file:line | stale content | action |
|---|---|---|---|
| S1 | `docs/claude/diataxis/reference/ash-configuration.md:14` | inline 13-domain list pinned to `config.exs:13-27` | regenerate to 19 domains, `config.exs:13-33`, re-date |
| S2 | `docs/claude/diataxis/reference/ash-configuration.md:58-81` | "The 13 real Ash domains" section | add sections for A2a, Conference, Graphlaw, Igniter, Security, Witness |
| S3 | `README.md:7` | "Thirteen Ash domains" | "Nineteen Ash domains" + updated list |
| S4 | `README.md:9-11` | snapshot pinned `main@c2a7ea9f` | re-observe at v26.10.6 SHA or drop the pin |
| S5 | `CHANGELOG.md` | stops at v26.9.28 | add v26.9.30 → v26.10.2 entries (or regenerate from git log per the file's own header convention) |
| S6 | `docs/claude/diataxis/reference/http-api-surface.md:5-8` | "verified 2026-09-22" + 62/56/45 counts | re-run the grep sweep, republish counts (currently 70 files), re-date |
| S7 | `http-api-surface.md:14-18,598` | browser surface omits `/marketplace-catalog` | add route |
| S8 | docs coverage of `Xaas.Witness` | absent | add a reference page (certified-receipt witness surface) or a diataxis index row |
| S9 | `priv/ash_surface/*.json` | emitted under `generatorIdentity ash_surface:v26.10.1`; ash_surface has moved | regenerate from ash_surface HEAD or record a digest manifest for the priv copies |
| S10 | `ash_surface/CHANGELOG.md` `[Unreleased]` | empty despite post-26.10.1 commits | backfill from git log |

Explicitly checked and NOT stale: `docs/claude/diataxis/reference/ultracode-runtime-contract.md:149`
("ggen_igniter surface declaration not yet emitted") — still accurate;
`admit_declaration/1` remains the admission seam. `docs/archive/**` ignored per audit
rules.

## Falsifier

Any row above is refuted by re-running the named command at HEAD and getting a
matching result: `shasum -a 256` for tables 1, `grep -rl 'base("/' lib/xaas | wc -l`
for D1/S6, domain count from `config/config.exs:13` for D3/S1, and
`git log --oneline v26.10.1..HEAD` in ash_surface for D9/S10.
