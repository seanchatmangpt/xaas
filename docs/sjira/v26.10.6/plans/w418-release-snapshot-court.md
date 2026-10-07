# W418 — release_snapshot verify court

Lane W418, v26.10.6 convergence campaign. Repo /Users/sac/xaas @ feat/playwright-surface.
Writes: this file + private `_build-laneW418` (removed at close).

## What verify needs

`mix xaas.release_snapshot.verify <snapshot.json>` (lib/mix/tasks/xaas.release_snapshot.verify.ex)
takes one frozen snapshot JSON artifact. There is no dedicated snapshot-generator mix task;
`mix xaas.release_audit` is an unrelated repo-wide contract audit (pinned to v26.8.21, would
refuse on current VERSION). The documented generation path is
`Xaas.Deployment.ReleaseSnapshot.freeze/2` + `Xaas.Deployment.ReleaseSnapshot.Codec.encode!/1`
(the same path the codec test exercises).

## Receipt

Exact subject: feat/playwright-surface @ d1db2b03 (working tree; no commits made).

Commands (all `PATH=$HOME/.asdf/shims:$PATH MIX_BUILD_ROOT=_build-laneW418 MIX_ENV=test`):

1. Mint artifact via `mix run -e` (freeze 2 members + provenance, `Codec.encode!` to
   `_build-laneW418/w418-release-snapshot.json`) — exit 0 after one corrected attempt
   (first attempt passed the `{:ok, member}` tuple from `member/1` un-unwrapped;
   `validate_members` refused with `{:invalid_member, {:ok, %Member{}}}` — user error,
   not a module defect).
   - snapshot_digest: `sha256:350dc06425cd50b89888309a490fecaeca43cee535b80a5bbffd71d9cd59152f`
   - closure_digest: `sha256:aff4fd97ae7f0ce3251765d4e6275a39903bad337cce9ba7a80bd6cbaa26d38f`
   - portable (JCS/RFC 8785) closure digest: `sha256:d79f535cbeff7dc1921cea5c3879861668f9b32436e3330e6ea31b3319758de7`
2. `mix xaas.release_snapshot.verify _build-laneW418/w418-release-snapshot.json` — exit 0:
   `{"schema":"xaas.release-snapshot-verdict/v1","authority":"none","closure_digest":"sha256:aff4...d38f","snapshot_digest":"sha256:350d...152f","member_count":2,"standing":"ALIVE"}`
   — recompute of both the term-based closure digest and the JCS portable digest over the
   decoded canonical JSON, so the canonical-JSON + digest path is genuinely exercised.
3. Test slice (grep -rl release_snapshot test/ → 3 files):
   `mix test test/xaas/deployment/release_snapshot_test.exs test/xaas/deployment/release_snapshot_codec_test.exs test/mix/tasks/xaas_refusal_render_test.exs`
   → `20 passed, 0 failed` (0.1s).

## Verdict

**release_snapshot verify court ALIVE** — green on the exact d1db2b03 subject: freeze →
JCS canonical encode → decode → verify (term digest + portable JCS digest recomputed and
matched), typed ALIVE verdict JSON with authority:"none".

## Cleanup

`rm -rf /Users/sac/xaas/_build-laneW418` **DENIED by the permission system** (session-scoped
denial on 2026-10-06). The lane build root (multi-GB, MIX_ENV=test) remains on disk at
/Users/sac/xaas/_build-laneW418 and must be removed by the coordinator at integration per
the cleanup law (same-checkout-fanout: lane build roots are leases, not assets).
