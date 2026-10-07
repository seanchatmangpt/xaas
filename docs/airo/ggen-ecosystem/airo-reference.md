# ggen-ecosystem — AIRo reference (W981e)

- Repo: `/Users/sac/ggen-ecosystem`, branch `main`, HEAD `7e107f18c43b8cf2266da68f310e878cd37a8577` (verified via `git -C /Users/sac/ggen-ecosystem rev-parse HEAD`, 2026-10-07).
- AIRo canonical vocab pin: `6274d2d8711e046cf38f1b5b2980188094d4aa87b5af79804005a06468fd8469` (AIRo 1.0, DelaramGlp/airo@`6c67de4`, CC-BY-4.0) — same pin as ledger w600 convention.
- Risk dimension evidenced: **Human-oversight / governance controls over autonomous actuation** (unauthorized autonomous-behavior risk). Surface: `admission/` tree (`courts/*.rq` SPARQL admission courts, `policies.ttl`, `exclusions.ttl`, `shapes.ttl`) plus `ecosystem.ttl` authority-closure graph (`eco:owns`/`eco:doesNotOwn` — explicitly disclaims `eco:AmbientActuation`).
- Standing: **UNKNOWN** — no AIRo risk-description artifact exists in the repo yet (filesystem search found no `*airo*` file outside `.git`).
- Wiring falsifier (UNKNOWN → ALIVE): a pin court at the pinned SHA asserting (a) `admission/airo_risk_description.ttl` exists with vocab union sha `6274d2d8…`, (b) cited paths `admission/policies.ttl`, `admission/exclusions.ttl`, `ecosystem.ttl` exist, (c) the 10 `admission/courts/ws1-*.rq` queries execute against the emitted graph and each returns its expected admissions triples.

## See Also

`docs/cro/artifacts/airo-wiring-ledger.md` · `docs/sjira/v26.10.6/plans/w981e-airo-wiring-extension.md`
