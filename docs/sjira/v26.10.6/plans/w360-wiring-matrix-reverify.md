# W360 — Wiring Matrix Re-Verification

Lane W360, v26.10.6 convergence, 2026-10-06. Read-only re-verification of every edge in
`_WIRING_MATRIX.md` (W164) against the live tree at `feat/playwright-surface` @ `d1db2b03`.
All verdicts below are from direct file reads on 2026-10-06; nothing copied from receipts.

## 1. Edge table

| # | edge (matrix row) | live evidence checked | verdict |
|---|---|---|---|
| 1 | xaas → ash_a2a git pin + `/a2a/v1` mount | `mix.exs:103-107` ref `86214551de93fc8ab395f5ed0b84d32922a5d99b`; `mix.lock:7` locked at same SHA. Mount: `router.ex:196-222` — `scope "/a2a"` forwards `/v1` → **`XaasWeb.A2A.V1TransportPlug`** (:215), not `AshA2A.Protocol.Plug`; hex `A2A.Plug` catch-all :220; module files `lib/xaas_web/a2a/*.ex` present; `e2e/a2a-v1.spec.cjs` targets the a2a surface | **STALE-PIN** — pin `86214551` ≠ sibling `~/ash_a2a` HEAD `07180bd3`; matrix row text also stale (names `AshA2A.Protocol.Plug`, live mount is the W305 `XaasWeb.A2A.V1TransportPlug` seam) |
| 2 | xaas → ash_pplan git-ref advance | `mix.exs:252-254` ref `5f10c9798b783c2023a6bfaa892c000630476f05` with the 2026-10-06 advance comment; `mix.lock:26` locked at same SHA; `lib/xaas/bridges/pplan.ex` present (consumes `AshPPlan.plan/1`, Facade, Durable Engine) | **STALE-PIN** — pin `5f10c97` ≠ sibling `~/ash_pplan` HEAD `414a393d` |
| 3 | xaas → ferroplan WASM digest pin | `lib/xaas/bridge/ferroplan.ex:31` `@pinned_sha256 "088d9c3b…"`; live `~/ferroplan/crates/ferroplan-wasm/registry/ferroplan_wasm.wasm` exists, `shasum -a 256` = `088d9c3b0306e36123ddc1ee780ad7e9d4bd2ebb54f9726c43f40a2f6d718233` — byte-identical | **WIRED** (ferroplan sibling HEAD `c0378768` has moved, but the edge is a content digest, not a SHA pin — digest reproduces exactly) |
| 3a | ferroplan-repo standing | n/a | DEV-ONLY note: repo HEAD moved to `c0378768`; artifact regenerable; digest edge unaffected |
| 4 | xaas → ggen consumer pin via `ggen.toml` | `ggen.toml:16-20` `[packs.xaas_castle_bridge]` git + version `518572b6b531…` + subdir `packs/xaas-castle-bridge-pack`; `~/ggen-marketplace/packs/xaas-castle-bridge-pack/` exists on disk; ggen repo HEAD `000bffb8f` matches r1/w81 receipts | **STALE-PIN** — marketplace SHA pin `518572b6` ≠ `~/ggen-marketplace` HEAD `93895f80` |
| 5 | ggen-marketplace selection authority + served catalog | `~/ggen-marketplace/marketplace.active.toml:4` `front_door = "ggen-platform-pack"`; `packs/ggen-platform-pack/` exists; xaas `router.ex:65` `live("/marketplace-catalog", MarketplaceCatalogLive)` + `lib/xaas_web/live/marketplace_catalog_live.ex` present; `e2e/marketplace.spec.ts:36` targets `/marketplace-catalog` | **WIRED** (pack dirs present; front-door law intact) |
| 6 | ash_surface path dep + alias + served projection | `mix.exs:115` `{:ash_surface, path: "../ash_surface"}`; `~/ash_surface` exists (HEAD `db5a8899`); alias `mix.exs:272` `ash_surface: ["xaas.ash_surface"]`; `priv/ash_surface/surface_contract.json` + runtime/client files present; `e2e/ash-surface-client.spec.cjs:22` `BASE = "/ash_surface"` | **WIRED** (path dep is HEAD-tracking by design — sibling HEAD `db5a8899` moves freely without a pin to go stale) |
| 6a | ash_graphlaw / ash_affidavit path deps | `mix.exs:114/116` path deps; `~/ash_graphlaw` (HEAD `1d89ba5f`) and `~/ash_affidavit` (HEAD `3bd7a4cb`) exist | **WIRED** |
| 7 | zcode-cli transport edge | `router.ex:127` `scope "/internal-api/fabric"`; `router.ex:258` `forward("/internal-api", XaasWeb.InternalApiRouter)`; `lib/xaas_web/internal_api_router.ex` present; `~/zcode-cli` HEAD `7fc62da` matches w58 receipt | **WIRED** (transport router-present; end-to-end CLI invocation still UNRUN per r7) |
| 8 | autofde-lab read-path edge | `lib/xaas/autofde/status_parser.ex:32` `@default_path ../autofde-lab/docs/STATUS.md`; live `~/autofde-lab/docs/STATUS.md` **exists on disk** | **WIRED** — matrix row 31's "program-path ENOENT gap" is now **stale text** for the STATUS.md read path; `config/dev.exs:190-194` program entry `path: ~/autofde-lab` resolves; r11's ENOENT no longer reproduces for the doc path |
| 8a | autofde-lab dev *program* path | `config/dev.exs` `"autofde-lab" => %{path: …}` | **DEV-ONLY** — read path wired; the dev program-entry gap r11 recorded appears closed on disk (STATUS.md present) but the program path itself was not exercised |
| 9 | gymact actuation adapter | `lib/xaas/operations/gymact_surface.ex` present; `~/gymact/src/gymact/surfaces/fastapi.py` present; `~/gymact` HEAD `d3eb5e84` | **WIRED** (module+target present on tree; standing still UNKNOWN end-to-end per r8 — no executed gate) |
| 10 | ggen_igniter hex dep | `mix.exs:226` `{:ggen_igniter, "~> 26.10.1"}`; `mix.lock:88` hex `26.10.1` sha256 `4a7fe00e…` matches matrix | **WIRED** as hex dep (typed UNSUPPORTED(PACK_NOT_SHIPPED) manufacture profile unchanged — per r3, not a wiring break) |
| 11 | ex4pm git pin | `mix.exs:245-248` ref `9f7aecda87e5110f668f824bbae760f6c97f88e1`; sibling `~/ex4pm` HEAD identical `9f7aecda` | **WIRED** — the only git pin that exactly equals sibling HEAD |
| 12 | xaas integration root | all bridge modules, router mounts, CI/mock-gate files present on tree | **WIRED** |

## 2. Proposed matrix corrections (not applied — matrix is read-only to this lane)

1. **Row ash_a2a (matrix line 15):** mechanism text names `AshA2A.Protocol.Plug` at
   `router.ex:211`; live mount at :215 is `XaasWeb.A2A.L1TransportPlug` (W305 owned-transport
   seam, vendored `Protocol.Plug` answers stream on a reply-backed agent with -32603).
   Correction: replace the `AshA2A.Protocol.Plug` module name with `XaasWeb.A2A.V1TransportPlug`,
   and add: sibling `~/ash_a2a` has advanced to `07180bd3` — pin `86214551` is the locked pin,
   sibling HEAD is not the pin.
2. **Row ash_pplan (line 16):** add STALE-PIN note: pin `5f10c97` ≠ sibling HEAD `414a393d`.
3. **Row ggen / ggen-marketplace (lines 18-19, §3):** add STALE-PIN note: `ggen.toml` marketplace
   SHA `518572b6` ≠ sibling HEAD `93895f80`.
4. **Row autofde-lab (line 31):** `~/autofde-lab/docs/STATUS.md` now exists; the ENOENT open item
   narrows to the dev program path only. Correction: downgrade the open ENOENT to DEV-ONLY.
5. **Row beam4pm/wasm4pm (lines 28-29):** not re-verified as wiring edges (typed NOT_REQUIRED);
   no correction proposed.

## 3. Counts

WIRED: 8 edges (ferroplan digest, marketplace front-door, ash_surface, ash_graphlaw/ash_affidavit, zcode-cli transport, autofde read-path, gymact adapter, ggen_igniter hex, ex4pm — 9 rows incl. sub-rows) · BROKEN(target missing): 0 · STALE-PIN: 3 (ash_a2a, ash_pplan, ggen-marketplace pin) · DEV-ONLY: 1 (autofde program path)

Zero BROKEN edges. The three STALE-PINs are the only correction-text rows the matrix needs.