# W924 — boot-guard contract cross-reference receipt

Lane W924. Subject: `/Users/sac/xaas`, branch `feat/playwright-surface`,
working tree on `a0723bf6` + campaign delta. No commit, no lane build root
(default `_build` under `MIX_ENV=test`, pinned asdf elixir
1.20.2-otp-28 via `PATH=$HOME/.asdf/shims`).

## 1. Δ

Docs-only, two files:
- `docs/sjira/v26.10.6/plans/w908-mixexs-version.md` — appended
  "Contract cross-reference (W924)" section (5 lines): the three layers of
  "required inputs fail loud and typed at every layer" — boot (mix.exs
  VERSION → `REFUSED(mix_boot, ...)`, W908), audit (`required_input!/1`,
  W872), scans (typed-absent findings, W845) — each with its receipt path.
- this receipt.

## 2. Falsifier (real run)

Happy path (VERSION present):
```
$ PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test mix compile   → EXIT=0
```
(with pre-existing warnings in `lib/xaas/semantics/dataset_admission.ex`;
exit 0, unrelated to this lane)

Mutation (VERSION moved aside):
```
$ mv VERSION /tmp/VERSION.w924
$ PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test mix compile
** (Mix.Error) REFUSED(mix_boot, detail: %{finding: "required project boot input VERSION unreadable: :enoent"})
    mix.exs:21: (module)
EXIT=1
$ mv /tmp/VERSION.w924 VERSION      # restored
$ git status --porcelain VERSION    → empty (byte-identical restore)
```

Non-vacuous: mutating exactly the guarded input flips exit 0→1 with the
typed refusal on stderr; first attempt piped through `tail` masked the exit
code, so the run was repeated capturing EXIT=1 directly.

## 3. Standing

- Contract note discoverable from w908: **ALIVE** (file on disk, verified
  by successful Edit).
- Boot guard still typed and loud on this subject: **ALIVE** (falsifier
  above).
- No code changed; W908/W872/W845 standing unchanged.
