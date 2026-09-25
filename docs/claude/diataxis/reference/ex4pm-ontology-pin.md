# ex4pm Ontology Pin

Reference for the config surface behind `Xaas.Ontology.Ex4pmStaleness` and
`mix xaas.telemetry.check_ontology_staleness`.

## What is pinned

`config :xaas, :ex4pm_ontology_check` in `config/config.exs` pins:

- `repo_path` - local ex4pm checkout (`$EX4PM_REPO_PATH` or `~/ex4pm`)
- `pinned_sha` - the exact ex4pm commit our vendored copy was taken from
- `upstream_path` - the upstream file path at that SHA
- `vendored_path` - our vendored copy's path in this repo

## Updating `pinned_sha`

Never re-vendor with a raw working-tree `cp` - the vendored file and the
pinned SHA must come from the same atomic `git show` so they can never
diverge from each other.

```bash
# 1. Confirm the upstream file has no uncommitted local changes.
git -C <ex4pm repo> status --porcelain -- <upstream_path>
# must print nothing

# 2. Resolve and confirm the exact commit SHA to pin.
git -C <ex4pm repo> rev-parse --verify HEAD^{commit}

# 3. Re-copy content from that exact SHA (not the working tree).
git -C <ex4pm repo> show <new_sha>:<upstream_path> > <vendored_path>
```

Then update `pinned_sha` in `config/config.exs` and commit the config
change together with the re-copied vendored file in one commit.

## Non-goals (v1)

See the `Xaas.Ontology.Ex4pmStaleness` moduledoc for the full list: this is
a byte-identical SHA-256 comparison only. It does not detect semantic-only
reformatting, does not follow renames, does not special-case LFS/gitlink/
symlink objects, and does not verify repo lineage beyond path + SHA.

## Running the check

```bash
mix xaas.telemetry.check_ontology_staleness
```

Exits 0 with `OK: ...` on a match, exits 0 with `UNSUPPORTED (skipped): ...`
when the ex4pm sibling repo is absent/unreachable (never a hard failure),
and exits non-zero with a named remediation only when ex4pm is present and
reachable but the pin is broken or content genuinely diverges.

The corresponding ExUnit test
(`test/xaas/ontology/ex4pm_staleness_test.exs`) is tagged `:external` and
excluded from the default `mix test` run; opt in explicitly with:

```bash
mix test --include external
```

## See also

- `lib/xaas/ontology/ex4pm_staleness.ex` - the shared check module
- `lib/mix/tasks/xaas.telemetry.check_ontology_staleness.ex` - the mix task
