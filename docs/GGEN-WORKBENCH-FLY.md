# Fly.io GGen Workbench

## Standing and boundary

The workbench turns xaas into a zero-install HTTP consumer of the composed
`ggen-ecosystem` runtime.

The worker image is pinned to:

- repository: `ghcr.io/seanchatmangpt/ggen-ecosystem`
- signed multi-arch index digest: `sha256:917eb72a031da073f1d7e0c1295cda6023171275d79674b6303d5d817a3d4cb0`
- observed publication run: `33926356178`
- observed platforms: linux/amd64 + linux/arm64, plus provenance attestations

The published index identity above is taken from the successful container
publication itself. During xaas verification, the older digest recorded in
`ggen-ecosystem/ecosystem.lock.toml` (`sha256:b9e170...`) was falsified as a
runnable multi-arch base: Docker returned `no match for platform in manifest`.
The workbench therefore binds receipts to the observed published index rather
than silently inheriting that stale/inconsistent lock field.

The HTTP call is **CONSTRUCT**, not ambient **DO**. A caller may provide only a
bounded file bundle and an argv vector for the `ggen` executable. The worker
executes `ggen` directly with `shell=false` inside a new temporary directory,
then destroys that directory after returning the manufactured files and
receipt. It accepts no executable selector, no shell program, no arbitrary
environment map, no Docker socket, and no GitHub/Fly/cloud credential.

Publishing generated files, pushing Git, deploying infrastructure, or applying
a cloud plan remains a separate BRCE-authorized actuation.

## Topology

```text
AGI / browser / API client
        |
        | HTTPS + INTERNAL_API_TOKEN
        v
Fly App: xaas control plane
        |
        | Fly private 6PN + GGEN_WORKBENCH_TOKEN
        v
Fly App: private workbench worker
  Dockerfile.workbench
        |
        | exact signed OCI index
        v
ghcr.io/seanchatmangpt/ggen-ecosystem@sha256:917eb72...
        |
        +--> ggen
        +--> ggen-marketplace packs
        +--> AutoFDE sources
        `--> beam4pm
```

The two Fly Apps must belong to the same Fly organization so their default 6PN
private network and `<worker-app>.internal` DNS relationship exist. The worker
has no public `http_service` or `services` stanza and listens on IPv6 for direct
6PN access from the xaas control plane.

The worker is a separate image because the current xaas BEAM release runner and
the ggen capsule are independently built Linux runtimes. Keeping them separate
preserves both runtime contracts rather than mixing libc/OpenSSL assumptions in
one final image.

## Runtime host identity

Fly injects `FLY_APP_NAME` into every Machine. Production Phoenix configuration
still gives explicit `PHX_HOST` precedence, but when it is absent xaas derives:

```text
<FLY_APP_NAME>.fly.dev
```

This keeps the externally allocated Fly app name out of committed configuration
without leaving the endpoint at the old `example.com` fallback on Fly.

## One-time Fly bootstrap

Two existing Fly Apps are required: a public xaas control-plane app and a
private workbench app. App names are not committed because they are externally
allocated global identities. Create both in the same Fly organization.

```sh
fly apps create <worker-app>
fly apps create <xaas-app>

TOKEN="$(openssl rand -hex 32)"

fly secrets set -a <worker-app> \
  GGEN_WORKBENCH_TOKEN="$TOKEN"

fly secrets set -a <xaas-app> \
  GGEN_WORKBENCH_TOKEN="$TOKEN" \
  GGEN_WORKBENCH_URL="http://<worker-app>.internal:8080" \
  INTERNAL_API_TOKEN="<client-bearer-token>" \
  DATABASE_URL="<postgres-url>" \
  SECRET_KEY_BASE="<phoenix-secret>" \
  ONETIME_REVOKE_KEY="<onetime-hmac-key>"
```

`DATABASE_URL`, `SECRET_KEY_BASE`, and `ONETIME_REVOKE_KEY` are not new
workbench requirements; the existing xaas production release already refuses
to boot without them.

After this one-time identity/secret bootstrap, neither an AGI client nor a
production deploy operator needs to install GGen, run the ggen-ecosystem
container, or install flyctl locally. The AGI uses HTTPS and production deploys
run through GitHub Actions.

## Receipted production deployment

`.github/workflows/fly_deploy.yaml` is the sole production deployment path. It
is deliberately `workflow_dispatch` only; merging or pushing does not acquire
production actuation authority by itself.

Configure these GitHub repository variables:

- `FLY_XAAS_APP` — the public xaas Fly App name;
- `FLY_WORKBENCH_APP` — the private worker Fly App name.

Configure these GitHub secrets:

- `FLY_XAAS_DEPLOY_TOKEN` — app-scoped Fly deploy token for xaas;
- `FLY_WORKBENCH_DEPLOY_TOKEN` — app-scoped Fly deploy token for the worker;
- `XAAS_INTERNAL_API_TOKEN` — the same value installed in the xaas Fly App as
  `INTERNAL_API_TOKEN`, used only for post-deploy end-to-end verification.

The workflow pins the Fly setup action to commit
`fc53c09e1bc3be6f54706524e3b82c4f462f77be` (release 1.5) and flyctl to
`0.4.99`.

A deployment requires two explicit inputs:

- `expected_head_sha` — must equal the exact selected `main` SHA;
- `reason` — operator-provided actuation reason included in the receipt.

The deployment sequence is:

1. admit `main`, exact expected SHA, app identities, and required credentials;
2. deploy the private worker with its app-scoped token;
3. observe worker Fly status;
4. deploy the xaas control plane with its app-scoped token;
5. observe xaas Fly status;
6. call public xaas `GET /api/workbench/ggen/health`;
7. call public xaas `POST /api/workbench/ggen` with real `ggen --version`;
8. require `ALIVE`, `admitted=true`, `executed=true`, `verified=true`, exit 0,
   and the exact admitted ggen-ecosystem index digest;
9. manufacture `xaas.fly-deploy.v1` with the exact repository SHA, app
   identities, operator reason, flyctl version, hashes of both Fly status
   observations, hashes of both end-to-end responses, and a receipt SHA-256;
10. publish that receipt in the GitHub Actions job summary.

The inherited automatic AWS deployment job has been removed. Fly is therefore
the sole production actuation topology introduced by this change.

## Pull-request verification

Normal xaas CI remains responsible for compile, tests, formatting, Dialyzer, and
unused-dependency checks. A separate `Verify pinned GGen workbench image` job
proves the new subject directly:

1. Python-compiles `fly/workbench_server.py`;
2. builds `Dockerfile.workbench`, forcing resolution of the exact OCI index;
3. executes the real `ggen --version` inside that image;
4. calls the worker's `execute` path against the real GGen binary;
5. requires an `ALIVE` construction result and a receipt bound to the exact
   configured digest and exit code 0.

The normal xaas image build/push cannot begin unless both the Elixir gate and
the workbench-image gate succeed.

### Falsifier already exercised

The first exact-head workbench-image gate used the old lock-recorded digest and
failed at Docker metadata resolution with `no match for platform in manifest`.
No GGen execution was claimed from that run. The repair pins the actual signed
OCI index emitted by publication run `33926356178`; the gate must rerun and
observe execution before the workbench subject can become `ALIVE`.

## Agent API

The existing `INTERNAL_API_TOKEN` protects the public workbench front door.

### Observe the exact runtime

```http
GET /api/workbench/ggen/health
Authorization: Bearer <INTERNAL_API_TOKEN>
```

A healthy response includes `ggen_ecosystem_digest`, the observed
`ggen --version`, exit code, and `ALIVE` standing.

### Execute GGen

```http
POST /api/workbench/ggen
Authorization: Bearer <INTERNAL_API_TOKEN>
Content-Type: application/json

{
  "args": ["sync", "run", "--dry-run"],
  "timeout_ms": 120000,
  "files": {
    "ggen.toml": "...",
    "ontology.ttl": "..."
  }
}
```

Binary inputs are represented as:

```json
{
  "files": {
    "fixture.bin": {
      "content_base64": "AAEC"
    }
  }
}
```

The worker never interprets `args` with a shell. It invokes the equivalent of
`execve("ggen", ["ggen", ...])`; characters such as `;`, `|`, `$()`, or `>`
remain literal GGen arguments.

## Response / construction receipt

Successful execution returns:

- the typed standing (`ALIVE` on exit 0, `BUILD_BROKEN` on a nonzero GGen exit);
- explicit observed/admitted/executed/changed/verified flags;
- bounded stdout and stderr plus truncation metadata;
- every new or changed workspace artifact, base64 encoded within the aggregate
  return limit;
- a deterministic receipt binding:
  - protocol version;
  - exact ggen-ecosystem index digest;
  - canonical request hash;
  - exact argv;
  - exit code;
  - stdout/stderr hashes;
  - artifact path/size/SHA-256 manifest;
  - receipt SHA-256.

The receipt makes the returned manufacture replay-comparable without granting
it external standing beyond the exact workbench execution.

## Admission limits

Both xaas and the private worker enforce the fence independently.

| Dimension | Limit |
| --- | ---: |
| GGen argv entries | 64 |
| Bytes per argv entry | 512 |
| Input files | 256 |
| Bytes per input file | 1 MiB |
| Aggregate input bytes | 5 MiB |
| HTTP request body | 6 MiB |
| Returned artifact content | 8 MiB |
| Captured stdout | 1 MiB |
| Captured stderr | 1 MiB |
| Execution timeout | 300 seconds |

The worker additionally limits individual files created by the child process to
32 MiB and disables core dumps.

## Falsifiers

The workbench is not `ALIVE` for a deployment merely because these files exist.
Promotion requires observed execution against the deployed subject:

1. worker `GET /healthz` executes the exact `ggen --version` and returns exit 0;
2. xaas `GET /api/workbench/ggen/health` reaches that private worker;
3. a real `POST /api/workbench/ggen` executes GGen through the hosted path;
4. the returned receipt binds the configured index digest and exit code;
5. a path-traversal request is refused;
6. the worker is not publicly routable;
7. the production deployment receipt binds the exact xaas head and both Fly
   app identities.

Until those deployed checks are observed against real Fly app identities,
repository implementation standing can be `PARTIAL_ALIVE`, but the Fly
deployment crown remains `BLOCKED`/`UNKNOWN` rather than inferred.
