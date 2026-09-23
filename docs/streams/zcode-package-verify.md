# Stream: zcode-package-verify

Branch `errc2/zcode-package` (worktree `/Users/sac/xaas-worktrees/errc/zcode-package-verify`),
base `2ec5fdb87ef1e144a1659628be148e3105efbd40`, merged `auto/zcode-package` (`5d8386f`) with
`git merge --no-ff`.

## Subject

`Xaas.Ultracode.ZcodePackage` admits `/Users/sac/dev/zcode-cli/package.json` (name
`zcode-app-cli`, `bin.zcode` inside the CLI dir and a regular file, `engines.node` parsed only as
`>=X.Y.Z`). `Dispatch.resolve_opts` and `scripts/xaas-glm-failover-dispatcher.sh`
(`zcode_package_preflight`) consume it.

## Fixed forward on top of the merge

- `mix format --check-formatted` failed on three files the candidate branch introduced
  (`zcode_package.ex`, `zcode_package_test.exs`, `wave_loop_test.exs`); formatted.
- Dispatcher preflight printed a Node stack trace when `package.json` was missing; it now reports
  `cli_unavailable: cannot read <path> (ENOENT)` and still exits 127.

## Added

- `ZcodePackage.verify_node/2` (returns the measured node version; `check_node/2` delegates to it),
  `version_string/1`, `default_cli_dir/0` (Dispatch now reads its default from there).
- `Xaas.Ultracode.ProviderHealth`: `check/1` returns
  `{:ok, %{zcode_version, zcode_bin, node_version}} | {:error, typed}`; `gate/1` returns
  `:ok | {:error, {:provider_unhealthy, typed}}`. No existing provider-health module existed
  (grep: only `TickHealth`, which is the Oban tick liveness check, a different subject). It is not
  yet wired into `Autonomic`; it is the seam a lease issuer calls.

## Falsifiers

- A `package.json` whose `name` is not `zcode-app-cli` must refuse (tested, and run through the
  shell preflight: exit 127).
- A node below `engines.node` must produce `{:node_too_old, ...}` (tested with `>=99.0.0`; shell
  preflight exit 127).
- The real CLI dir must admit on this machine (tested against the real directory).
