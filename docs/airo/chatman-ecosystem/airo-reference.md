# chatman-ecosystem — AIRo reference (W981e)

- Repo: `/Users/sac/chatman-ecosystem`, branch `docs/v27927-closed-manufacture-loop`, HEAD `83ceef8a862a423917e84a8713500745ab162dad` (verified via `git -C /Users/sac/chatman-ecosystem rev-parse HEAD`, 2026-10-07).
- AIRo canonical vocab pin: `6274d2d8711e046cf38f1b5b2980188094d4aa87b5af79804005a06468fd8469` (AIRo 1.0, DelaramGlp/airo@`6c67de4`, CC-BY-4.0) — same pin as ledger w600 convention.
- Risk dimension evidenced: **Control over autonomous-agent actuation authority** (unauthorized autonomous-action risk). Surface: `crates/gall` — the gall actuator with an explicit authority boundary (`ecosystem.lock`, `src/`, `tests/`), the same governed-actuator pattern as `zcode-cli:src/gall-work.ts` (composition primitive D, typed authority ceilings + leases).
- Standing: **UNKNOWN** — no AIRo risk-description artifact exists in the repo yet (filesystem search found no `*airo*` file outside `.git`).
- Wiring falsifier (UNKNOWN → ALIVE): a pin court at the pinned SHA asserting (a) `crates/gall/airo_risk_description.ttl` exists with vocab union sha `6274d2d8…`, (b) cited paths `crates/gall/src/`, `crates/gall/tests/`, `crates/gall/ecosystem.lock` exist, (c) `cargo test -p gall` passes at the pinned SHA with the court asserting the authority-boundary paths cited in the risk description.

## See Also

`docs/cro/artifacts/airo-wiring-ledger.md` · `docs/sjira/v26.10.6/plans/w981e-airo-wiring-extension.md`
