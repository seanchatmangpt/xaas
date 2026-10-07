# W908 — mix.exs:13 unguarded `File.read!("VERSION")` → typed boot refusal

Lane W908. Subject: `/Users/sac/xaas`, branch `feat/playwright-surface`, HEAD
`a0723bf6` + working-tree delta confined to `mix.exs` (line-13 block only) and
this receipt file. Build: `MIX_ENV=test MIX_BUILD_ROOT=_build-laneW908`,
elixir 1.20.2-otp-28 via asdf (`PATH=$HOME/.asdf/shims`). No commit (per lane
contract; coordinator owns integration).

Residual from W872 (`docs/sjira/v26.10.6/plans/w872-audit-residuals.md` §1
final note): the compile-time `@version File.read!("VERSION")` in `mix.exs`
was the only surviving untyped crash site — mix re-evaluates `mix.exs` on
every invocation, so an absent VERSION raised `** (File.Error) could not read
file "VERSION": no such file or directory — mix.exs:13` before any task ran.

## 1. Repair (μ/diff)

`mix.exs` only. The unguarded module-attribute read became a guarded case at
the same site:

```elixir
version =
  case File.read("VERSION") do
    {:ok, contents} -> String.trim(contents)
    {:error, reason} ->
      Mix.raise(
        "REFUSED(mix_boot, detail: %{finding: \"required project boot input VERSION unreadable: #{inspect(reason)}\"})"
      )
  end

@version version
```

Shape matches W872's `required_input!/1` refusal string
(`REFUSED(<scope>, detail: %{finding: "required ... input <name> unreadable: <reason>"})`)
adapted to project boot scope (`mix_boot`). Behavior when VERSION is present
is byte-identical: same `String.trim/1`, same `@version` value; the read is
still a single compile-time evaluation before `project/0`.

## 2. Falsifiers (real runs)

### F-A. VERSION moved aside → typed refusal naming VERSION

```
$ mv VERSION /tmp/VERSION.w908
$ mix xaas.release_audit
** (Mix.Error) REFUSED(mix_boot, detail: %{finding: "required project boot input VERSION unreadable: :enoent"})
EXIT=1
```

Previously: `** (File.Error) could not read file "VERSION": no such file or
directory — mix.exs:13` (untyped). Now loud, fail-closed, and typed, naming
the missing required boot input and the reason.

### F-B. VERSION restored → identical boot

```
$ mv /tmp/VERSION.w908 VERSION
$ mix compile
EXIT=0            (no output — same as pre-lane clean compile)
$ git status --porcelain VERSION   → empty (byte-identical restore)
```

### F-C. Regression

`mix test test/mix/tasks/xaas_release_audit_test.exs` → **4 passed, 0 failed**,
EXIT=0 (includes the shape/derivation tests that pin the VERSION-file
derivation; the `mix.exs:13 shape` regex in that file pins the release_audit
task's own `@version`, not mix.exs, and still passes unchanged).

## 3. Mutation rationale

The falsifier mutates exactly the input the guard reads (VERSION moved aside),
so a vacuous guard (case never refuses) would leave the old `File.Error` on
stderr and exit≠1-typed. Captured output shows the typed `Mix.Error` line, so
the refusal is non-vacuous. Restoration proves no behavioral drift on the
happy path.

## Contract cross-reference (W924)

"Required inputs fail loud and typed at every layer": (1) boot — mix.exs
VERSION read → `REFUSED(mix_boot, ...)` (W908, this receipt); (2) audit —
`required_input!/1` in `xaas.release_audit` (`w872-audit-residuals.md`);
(3) scans — typed-absent findings (`w845-audit-enoent.md`).
Falsifier re-witnessed: `w924-boot-guard-note.md`.

## 4. Standing

- Guarded boot refusal: **ALIVE** — falsifier F-A witnessed on this lane's
  build (`_build-laneW908`).
- Happy-path identity: **ALIVE** — F-B compile exit 0 + unchanged test run.
- Residual: none known. W872's three task-level unguarded reads and this
  boot-level site are all typed; no `File.read!` on required inputs remains
  in the mix boot/audit path.
