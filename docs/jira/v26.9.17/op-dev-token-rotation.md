# OP Dev Token Rotation — ZCODE_XAAS leak remediation (operator act + resync)

## Summary

The hook-court agent printed the dev-local `ZCODE_XAAS_TOKEN` value once into
its session transcript (self-disclosed deviation). Scope is dev-local, but the
token must be rotated before any non-dev use. The token's delivery surfaces
are now: (a) server env `INTERNAL_API_TOKEN`, (b) plugin user-config option
`zcode_xaas_token` in `~/.zcode/cli/config.json` `plugins.options`, (c) session
shell env `ZCODE_XAAS_TOKEN` consumed by hook scripts at execution time.

## Status

BLOCKED — awaiting operator act (secret rotation).

## Scope

1. Operator generates a new token and sets it as the running server's
   `INTERNAL_API_TOKEN` (with the `op-xaas-server-restart.md` cut, ideally the
   same restart).
2. Resync the ZCode side (value never printed):
   ```bash
   # write {"zcode_xaas_token": "<new>"} to a 0600 file, then:
   zcode plugins configure xaas-fabric@xaas-fabric-marketplace --options-file <file>
   rm <file>
   export ZCODE_XAAS_TOKEN=<new>   # in the shell profile that launches zcode
   ```
3. Agent verification slice: no-token 401, authenticated `initialize` 200 with
   the NEW value; old value → 401.
4. Check no other copies exist (`~/.zcode` config backup at
   `/tmp/uzc/config.json.bak-20260917` still holds the old literal header —
   destroy or rotate-away that file).

## Key Invariant(s)

- The token exists in exactly three lawful places: server env, plugin options,
  launching shell env. No literals in any tree, transcript, or backup.
- Rotation must not weaken the fail-closed gates (unset → 503 stays).

## Relationship to Existing Work

- `hook-court.md` §5 (the leak + recommendation); `zcode-connection-P0P1.md`
  (the user_config plumbing this ticket re-syncs).
- Prerequisite for any non-dev exposure of the execution fabric.

## Falsifiers / What Would Defeat This

- Old token still authenticates after rotation (stale copy somewhere).
- New token appears in any file under version control.

## History

| ts | standing | branch+SHA | gates+exits | remaining |
|---|---|---|---|---|
| 2026-09-17T12:30-07:00 | BLOCKED | n/a (secrets plane) | leak witnessed once, dev-local, disclosed | rotate + 3-surface resync + verify |
