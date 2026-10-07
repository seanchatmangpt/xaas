# W42 — Xaas.Operations.GymactSurface adapter (receipt)

Lane: W42 (wave 2). Subject: /Users/sac/xaas @ feat/playwright-surface. Written by the coordinator from the lane's completion report (2026-10-06).

## What landed
- `lib/xaas/operations/gymact_surface.ex` (hand-written): fail-closed adapter over gymact's FastAPI surface — `config/0`, `health/0`, `providers/0`, `prepare_candidate/1`, `open_episode/1`, `capabilities/1`, `submit_action/2`, `verify/2`, `actuate/4`, `actuate_local/4`; all refuse `{:error, %Xaas.Actuation.Refusal{code: :gymact_not_configured}}` when `:xaas, :gymact_surface` absent. No string scraping; no `:actuate_status` contact.
- Mutations behind the actuation ledger: `actuate/4` = external three-commit protocol (`Xaas.Actuation.prepare_external` → gymact HTTP DO via `submit_action` → `Xaas.Actuation.seal_external`) with required idempotency key + explicit authority. `actuate_local/4` = gated `run/4` passthrough for local-Ash riders. Canonical DO port `/actions/selected` takes an opaque court-manufactured cut.
- `test/xaas/operations/gymact_surface_test.exs`: 9 tests, zero mocks — 4 typed-refusal + 5 real-HTTP against a real `~/gymact/.venv/bin/uvicorn --factory gymact.surfaces.fastapi:create_app` subprocess per test (free-port mint, health-poll, pkill cleanup).

## Gates (real, verbatim)
- `MIX_ENV=test mix compile` clean; `mix test test/xaas/operations/gymact_surface_test.exs` → **9 passed, 0 failures**. Witnessed: `/health` → `{"status":"ALIVE","version":"26.10.6"}`, `POST /episodes` full receipted materialization, `verify` → `passed == true`.

## Coordinator seams
- Config line landed post-lane (coordinator): `config :xaas, :gymact_surface, base_url: "http://127.0.0.1:8000"` in config/config.exs. Tokenless = typed refusal (fail-closed).
- Open (deliberately out of lane): court-manufactured cut builder for an end-to-end `actuate/4` happy-path court.
