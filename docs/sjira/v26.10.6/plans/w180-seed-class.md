# W180 — seed-dependent failure class closure receipt

- Subject: /Users/sac/xaas @ feat/playwright-surface (HEAD d1db2b03)
- Scope: W70 seed-dependent class — full_surface ×3, marketplace ×4, chicago-pplan-deep successor standing
- Pre-step: killed stale beam on :4000 (authorized); port confirmed clear
- Seed: global-setup ran — `marketplace catalog written: .../xaas-e2e-marketplace-catalog.json (13 packs)` (log line observed); witness seeded via global-setup
- Command: `PATH=$HOME/.asdf/shims:$PATH INTERNAL_API_TOKEN=dev-e2e-token npx playwright test e2e/full_surface.spec.ts e2e/marketplace.spec.ts e2e/chicago-pplan-deep.spec.cjs` (EXIT=1)

## Per-file counts (27 total)

| file | pass | fail |
|---|---|---|
| e2e/full_surface.spec.ts | 11 | 0 |
| e2e/marketplace.spec.ts | 4 | 0 |
| e2e/chicago-pplan-deep.spec.cjs | 11 | 1 |

**26 passed / 1 failed** (1.4m).

## Verdict

W70 seed-dependent class: **CLOSED**. full_surface (3/3 previously failing → 11/11 pass) and
marketplace (4/4 previously failing → 4/4 pass) are green with global-setup seeding. The
chicago-pplan-deep successor-vocabulary assertions (W117 fix) hold — no successor-standing
failures observed.

## Residual (classified, NOT seed-class)

`e2e/chicago-pplan-deep.spec.cjs:194` — "/chicago/seller — executive projection (SellerLive) ›
renders 10 candidate cards, 2 successor cards, empty demonstrated list":

```
Error: expect(locator).toHaveCount(expected) failed
Locator:  locator('[data-testid^="chicago-evidence-"]')
Expected: 12
Received: 48
e2e/chicago-pplan-deep.spec.cjs:246:70
```

Classification: presentation/count assertion drift — the seller projection renders 48
evidence cards vs the test's expected 12 (4x). Not seed-dependent (failure is a count
mismatch on rendered DOM, not missing seed data). Candidate causes: evidence cards rendered
per-candidate × per-successor (10+2 candidates × rows) where the assertion predates a
multiplication of the surface, or duplicated `chicago-evidence-` testids. Follow-up lane
should re-derive the expected count from SellerLive's projection or fix the assertion.
