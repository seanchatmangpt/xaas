# Fly.io GGen Workbench

## Standing and boundary

The workbench turns xaas into a zero-install HTTP consumer of the composed
`ggen-ecosystem` runtime.

The worker image is pinned to:

- repository: `ghcr.io/seanchatmangpt/ggen-ecosystem`
- digest: `sha256:b9e170233fe15d91003fbfc322786534d208fe8ac1b5c58cc0702d88d9ceeb3c`
- ggen-ecosystem lock standing at admission time: `ALIVE`
- observed multi-arch publication: linux/amd64 + linux/arm64 + merged manifest

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
        | exact OCI digest
        v
ghcr.io/seanchatmangpt/ggen-ecosystem@sha256:b9e170...
        |
        +--> ggen
        +--> ggen-marketplace packs
        +--> AutoFDE sources
        `--> beam4pm
```

The worker is a separate image because the current xaas BEAM release runner and
the ggen capsule are independently built Linux runtimes. Keeping them separate
preserves both runtime contracts rather than mixing libc/OpenSSL assumptions in
one final image.

## One-time Fly bootstrap

Two Fly Apps are used: a public xaas control-plane app and a private workbench
app. App names are not committed because they are externally allocated global
identities.

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

fly deploy -a <worker-app> -c fly.workbench.toml
fly deploy -a <xaas-app> -c fly.toml
```

`DATABASE_URL`, `SECRET_KEY_BASE`, and `ONETIME_REVOKE_KEY` are not new
workbench requirements; the existing xaas production release already refuses
to boot without them.

The private worker config has no public `http_service` or `services` stanza.
The control plane reaches it through `<worker-app>.internal`.

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
  - exact ggen-ecosystem digest;
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
3. a real `POST /api/workbench/ggen` with admitted `ggen.toml` and
   `ontology.ttl` executes `ggen sync run --dry-run`;
4. the returned receipt binds the configured digest and exit code;
5. a path-traversal request is refused;
6. the worker is not publicly routable.

Until those deployed checks are observed, repository implementation standing is
`PARTIAL_ALIVE`, not a deployment crown.
