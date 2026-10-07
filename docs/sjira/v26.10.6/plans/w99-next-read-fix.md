# W99 Receipt — next-read Playwright fix (v26.10.6 convergence)

*Backfilled by coordinator from lane completion report.*

- **Repo**: /Users/sac/xaas
- **Root cause**: clicks fired before the LiveView websocket connected
  (`networkidle` ≠ phx-connected).
- **Fix**: `gotoNextRead` helper waits for `[data-phx-main].phx-connected`.
- **Test hardening**: pin test by `data-book-id`; checkout-or-hold path per catalog state.
- **Gate**: gate 18 passed (`--repeat-each=3`); ExUnit 3 passed (no app regression).
