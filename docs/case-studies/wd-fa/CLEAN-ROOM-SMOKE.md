# Clean-Room Smoke

A final Friday candidate SHOULD be tested from a clean clone/worktree.

## Required smoke sequence

```
git rev-parse HEAD
mix deps.get --check-locked
npm ci
mix ecto.create
mix ecto.migrate
mix compile --force --warnings-as-errors
mix test test/xaas/case_studies/wd_fa_chicago_test.exs
mix test test/xaas/case_studies/wd_fa_stogaf*.exs
mix test test/xaas_web/controllers/wd_fa_stogaf_controller_test.exs
npx playwright install --with-deps chromium
# start Phoenix
npx playwright test e2e/wd-fa-cs2.spec.cjs
STOGAF_SUBJECT_SHA=$(git rev-parse HEAD) mix xaas.wd.stogaf_receipt
```

No local uncommitted file may be required for the smoke to pass.
