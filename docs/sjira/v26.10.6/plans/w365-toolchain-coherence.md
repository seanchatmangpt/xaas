# W365 — Toolchain Coherence Precondition Audit (DoD 1)

Subject: fleet checkouts under $HOME, read-only sweep. Date: 2026-10-06.
Expected pin: `elixir 1.20.2-otp-28 / erlang 28.5.0.2` (xaas canonical).

## 1. Per-repo `.tool-versions`

| repo | .tool-versions | elixir | erlang | vs pin |
|---|---|---|---|---|
| xaas | yes | 1.20.2-otp-28 | 28.5.0.2 | = pin |
| ash_surface | yes | 1.20.3-otp-28 | 28.3 | DEVIATES (elixir patch +1, erlang minor) |
| ash_a2a | yes | 1.20.4-otp-29 | 29.1.1 | DEVIATES (OTP 29) |
| ash_pplan | yes (ggen-generated, toolchain-unify-pack, choice-2026-10-01) | 1.20.4-otp-29 | 29.1.1 | DEVIATES (OTP 29) |
| ash_r2rml | yes | 1.18.4-otp-27 | 27.2.4 | DEVIATES (OTP 27, elixir 1.18) |
| ex4pm | yes (ggen-generated, toolchain-unify-pack, choice-2026-10-01) | 1.20.4-otp-29 | 29.1.1 | DEVIATES (OTP 29) |
| beam4pm | yes (ggen-generated, toolchain-unify-pack, choice-2026-10-01) | 1.20.4-otp-29 | 29.1.1 | DEVIATES (OTP 29) |
| ggen_igniter | yes | 1.19.5-otp-27 | 27.2.4 | DEVIATES (OTP 27, elixir 1.19) |
| ggen-marketplace | **MISSING** | — | — | FINDING: receipts in that repo have no pinned toolchain |

Only xaas matches the expected pin. Note the OTP-29 cluster (ash_a2a, ash_pplan,
ex4pm, beam4pm) is ggen-generated from `tu:ToolchainChoice choice-2026-10-01`
in ggen-marketplace toolchain-unify-pack — a deliberate unification decision,
not drift; but it contradicts the campaign's stated expected pin.

## 2. Active toolchain (from /Users/sac/xaas)

```
asdf current:
  elixir  1.20.2-otp-28  (xaas .tool-versions)
  erlang  28.5.0.2       (xaas .tool-versions)
  + age/awscli/github-cli/jq/packer pinned in xaas
elixir --version:
  Erlang/OTP 28 [erts-16.4.0.2]
  Elixir 1.20.2 (compiled with Erlang/OTP 28)
```

Active toolchain = xaas pin. Any fleet work run with this PATH against an
OTP-29 repo is a cross-toolchain compile hazard (cf. the known `_build`
corruption warning in xaas/CLAUDE.md).

## 3. Permission-bit spot check (OS-11 probe)

`find <repo>/priv <repo>/deps -maxdepth 2 -type d` counts, per repo:

| repo | ! -perm -u+r (owner-unreadable) | ! -perm -o+rx (group/other denied) |
|---|---|---|
| xaas | 0 | 64 |
| ash_surface | 0 | 18 |
| ash_a2a | 0 | 38 |
| ash_pplan | 0 | 25 |
| ash_r2rml | 0 | 13 |
| ex4pm | 0 | 18 |
| beam4pm | 0 | 30 |
| ggen_igniter | 0 | 26 |
| ggen-marketplace | 0 | 0 |

- **Owner-unreadable (u+r) count = 0 everywhere → no OS-11 recurrence** on the
  primary probe (the class that actually blocks builds running as owner).
- The `! -perm -o+rx` variant fires on 232 dirs fleet-wide. Sampled:
  `drwx------` (0700) e.g. `/Users/sac/xaas/priv`, `/Users/sac/xaas/deps/ex_aws/priv`,
  `/Users/sac/xaas/deps/cowboy/src`. This is
  systemic (owner-only 0700), not scattered corruption: every dir is fully
  accessible to owner `sac`, so owner-context receipts are unaffected. It would
  break any build run as a different user.

## 4. Homebrew shadow check

- bare PATH `which mix` → `/opt/homebrew/bin/mix` (Homebrew OTP 28 / erts 16.2)
- `$HOME/.asdf/shims/mix` → Mix 1.20.2 on OTP 28 / erts **16.4.0.2**

Shadow CONFIRMED still present; the PATH-prefix discipline is load-bearing
(erts build mismatch 16.2 vs 16.4.0.2 between the two "OTP 28" mixes).

## Verdict

- OS-11 recurrence: **none** (u+r = 0 in all 9 repos).
- Pin deviation: 8 of 9 repos deviate from elixir 1.20.2-otp-28 / erlang
  28.5.0.2; ggen-marketplace has no pin at all. OTP-29 quartet is
  ggen-generated unification (choice-2026-10-01), not drift.
- Shadow: confirmed; PATH-prefix discipline remains required.
