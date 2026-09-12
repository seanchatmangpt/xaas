# Next Read — Definition of Done

Acceptance checklist for the "Next Read" case study (`Xaas.Library` Ash domain:
Book/Checkout/Curation resources, Ranker, Embeddings via Nx/Bumblebee, ILSRepo +
Explainer disclosed substitutions, two LiveViews under
`lib/xaas_web/live/next_read/` subscribing to PubSub for realtime updates).
Grounded in `~/CLAUDE.md` and `/Users/sac/xaas/CLAUDE.md`'s standing verification
discipline. Every item below is unchecked by design — this document defines "done,"
it does not claim anything is done. A future verification pass checks these boxes
against real command output, not description of output.

## Checklist

- [ ] `mix compile --force` clean (no warnings treated as passing; a real compile
      run, not source inspection)
- [ ] `mix test test/xaas/library/` green — ranker unit tests + resource/policy
      tests, using real Postgres via `Ecto.Adapters.SQL.Sandbox`, real Ash actions,
      no mocking libraries or owned-collaborator interaction fakes. Required grep,
      zero new matches under `lib/xaas/library` and `test/xaas/library`:
      ```bash
      grep -rn "unittest.mock\|Mock(\|MagicMock\|patch(\|monkeypatch\|Mox\b\|:meck\|meck\." test/ lib/
      ```
- [ ] `mix test test/xaas_web/live/next_read/` green — the two-LiveView realtime
      scenario (librarian pins in one LiveView process, student LiveView's rendered
      HTML updates without a page reload) is the automated proof of the deck's
      "no refresh" claim (slides 16 and 18), not a description of that behavior
- [ ] `mix test` (full suite) has no new regressions elsewhere in the repo —
      pre-existing failures, if any, are distinguished explicitly from failures
      introduced by this case study, not folded together
- [ ] Deny-by-default Ash policy floor present on every new resource (a scoped
      read carve-out uses `bypass`; the floor otherwise stays a trailing
      `policy always() do forbid_if always() end)`, no ambient allow-all)
- [ ] The two disclosed substitutions (ILS, Explainer) are named in
      `docs/case-studies/next-read/ILS-AND-EXPLANATION-SUBSTITUTION.md`, not
      silently passed off as real integrations
- [ ] `docs/case-studies/next-read/README.md` correctly distinguishes real code
      from scenario placeholders (slide 4 baselines named explicitly as
      placeholders, not real measured numbers)
- [ ] Manual walkthrough of the deck's slide-18 eight-cue live-demo script against
      the real running app (`mix phx.server`, two browser tabs) matches the deck,
      cue by cue — a run, not a survey of whether it should work
- [ ] No unfulfilled TODOs/stubs silently left in `lib/xaas/library/` without an
      explicit disclosure comment naming what's stubbed and why

## See also

- `docs/case-studies/next-read/README.md`
- `docs/case-studies/next-read/ILS-AND-EXPLANATION-SUBSTITUTION.md`
- `/Users/sac/xaas/CLAUDE.md` — Chicago-style testing, Ash policy floor, claims-require-execution discipline this checklist reflects
