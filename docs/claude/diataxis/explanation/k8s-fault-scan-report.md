# k8s Fault-Scan Report — kind-xaas (2026-08-20)

Real security/fault scan against the live `kind-xaas` cluster. Scan-and-report only —
nothing in `k8s/` was applied to the cluster during this task.

## Cluster verified up

```
$ kind get clusters
platform-eng-colima
xaas
$ kubectl config current-context
kind-xaas
$ kubectl get nodes -o wide
NAME                 STATUS   ROLES           AGE   VERSION
xaas-control-plane   Ready    control-plane   8h    v1.34.0
```

Single-node kind cluster, containerd runtime, kindnet CNI. Workloads present in `default`:
`xaas` (Deployment, app), `postgres` (Deployment), `prometheus` (Deployment).

## Tools used

- `kubectl get pods -A -o json` + a real Python pass over the JSON — container
  `securityContext`, `hostNetwork`/`hostPID`/`hostIPC`, resource limits/requests.
- `kubectl auth can-i --list --as=system:serviceaccount:default:default` — real RBAC
  check for the identity the `xaas`/`postgres`/`prometheus` pods actually run as.
- `kubectl get rolebinding -A` / `clusterrolebinding -o json` — real bindings inventory.
- `trivy k8s kind-xaas --report all --scanners misconfig` — **actually ran**, not a
  fallback. `which trivy` found `/opt/homebrew/bin/trivy`; `kube-bench` is genuinely
  absent (`which kube-bench` → not found) and was not installed (would need a
  privileged host-level scan not appropriate for this sandboxed check anyway) — trivy's
  misconfig scanner covers the same CIS-adjacent pod-hardening checks kube-bench's
  workload checks would, so no functional gap for this report.
- `scripts/verify-etcd-encryption.sh default xaas-secrets` (pre-existing script in this
  repo) — real raw `etcdctl get` byte dump of the Secret key.

## Findings

### 1. No pod in `default` sets a security context — CONFIRMED (HIGH)

Verified two independent ways:

**a) Direct inspection of live pod specs** (`kubectl get pods -A -o json`, Python pass):

```
default/postgres-...   container=postgres   -> runAsNonRoot!=true, allowPrivilegeEscalation!=false,
                                                 readOnlyRootFilesystem!=true, NO resource limits, NO resource requests
default/prometheus-... container=prometheus -> runAsNonRoot!=true, allowPrivilegeEscalation!=false,
                                                 readOnlyRootFilesystem!=true, NO resource limits, NO resource requests
default/xaas-...       container=xaas       -> runAsNonRoot!=true, allowPrivilegeEscalation!=false,
                                                 readOnlyRootFilesystem!=true
```

(`xaas` does have resource limits/requests already set live — 100m/500m cpu, 128Mi/1Gi
mem — matching what `k8s/resource-quotas.yaml`'s header comment claims was live-patched
this session. `postgres` and `prometheus` do not.)

**b) `grep -n -i "securityContext" k8s/deployment.yaml k8s/postgres.yaml k8s/prometheus.yaml`
→ zero matches** — none of the three manifest files that produced these live Deployments
ever set a `securityContext` block, container- or pod-level. The live gap traces directly
to the source manifests, not to a live drift from an already-hardened file.

**c) Real trivy misconfig scan** (`trivy k8s kind-xaas --report all --include-namespaces
default --scanners misconfig`) confirms the same gap with named checks, for all three
Deployments:

```
namespace: default, deployment: xaas (kubernetes)
Tests: 42 (SUCCESSES: 36, FAILURES: 6)
Failures: 6 (MEDIUM: 3, HIGH: 3, CRITICAL: 0)

AVD-KSV-0001 (MEDIUM): should set 'securityContext.allowPrivilegeEscalation' to false
AVD-KSV-0012 (MEDIUM): should set 'securityContext.runAsNonRoot' to true
AVD-KSV-0014 (HIGH):   should set 'securityContext.readOnlyRootFilesystem' to true
AVD-KSV-0104 (MEDIUM): should specify a seccomp profile
AVD-KSV-0118 (HIGH):   container xaas is using the default security context
AVD-KSV-0118 (HIGH):   deployment xaas is using the default security context, which allows root privileges
```

Identical 6-finding set (same AVD IDs) for `postgres` and `prometheus`. `prometheus` gets
a 7th: `AVD-KSV-0125 (MEDIUM)` — image `prom/prometheus:v2.53.0` from an "untrusted
registry" per trivy's default allow-list (Docker Hub, not a pinned/verified registry).
`xaas-config` ConfigMap also flags `AVD-KSV-01010 (MEDIUM)`: stores `PORT` as a key,
trivy's heuristic for "looks like it might be sensitive" — reviewed manually, this one is
a false positive (PORT is not sensitive), noted for completeness rather than as a real gap.

**No CRITICAL findings** in the trivy misconfig or RBAC/infra assessments (RBAC/Infra
tables both came back empty — 0 checks failed).

### 2. Pods run as the `default` ServiceAccount — CONFIRMED, but currently low-risk (MEDIUM)

```
$ kubectl get pod -n default -l app=xaas -o jsonpath='{.spec.serviceAccountName}'
default
$ kubectl get sa -n default
NAME      SECRETS   AGE
default   0         8h
$ kubectl get rolebinding -A   # no binding anywhere references default:default
$ kubectl get clusterrolebinding -o json | <filter subjects.namespace=default>
# zero matches
```

Real check of what the `default` SA can actually do (`kubectl auth can-i --list
--as=system:serviceaccount:default:default -n default`): only the universal
unauthenticated-safe verbs (`selfsubjectreviews`, discovery endpoints like `/api`,
`/healthz`, `/version`) — **no read/write access to any namespaced or cluster resource**.
So today this is not an active over-permission (the `default` SA in this cluster happens
to carry no bound Role/ClusterRole), but it's still the wrong identity for the workload:
any future RoleBinding added to the `default` SA (a common accretion pattern — someone
grants `default` broad read access "just for debugging" and forgets) is immediately
inherited by every pod in the namespace, including `xaas`, `postgres`, and `prometheus`.
`k8s/rbac.yaml` (see below) exists to close this by giving `xaas` its own named identity
and scoping it to exactly the two objects it consumes.

`automountServiceAccountToken` is unset (defaults to `true`) on the `xaas` Deployment —
confirmed via `kubectl get deploy xaas -o jsonpath='{.spec.template.spec.automountServiceAccountToken}'`
returning empty. Combined with finding 2, the `xaas` pod does have a live, mounted token
for an SA that (today) grants nothing extra — not an active exposure, but worth noting for
completeness since token automount is itself a commonly-flagged CIS/kube-bench item.

### 3. etcd encryption at rest — FIXED, CONFIRMED (2026-08-20 update)

**Original finding (as first written, now superseded below):** Ran
`scripts/verify-etcd-encryption.sh default xaas-secrets` (pre-existing repo script)
against the live cluster's etcd via a real `etcdctl get --print-value-only` of
`/registry/secrets/default/xaas-secrets`, followed by a byte-level scan of the raw output
for plaintext leakage of the real secret key names/values:

```
envelope prefix present: False
plaintext leaks found:   [('key-name', 'DATABASE_URL'), ('value', 'DATABASE_URL'),
                           ('key-name', 'INTERNAL_API_TOKEN'), ('value', 'INTERNAL_API_TOKEN'),
                           ('key-name', 'ONETIME_REVOKE_KEY'), ('value', 'ONETIME_REVOKE_KEY'),
                           ('key-name', 'POSTGRES_PASSWORD'),
                           ('key-name', 'SECRET_KEY_BASE'), ('value', 'SECRET_KEY_BASE')]
RESULT: NOT CONFIRMED -- investigate
```

Reading past the script's own summary line: `envelope prefix present: False` means the
etcd-stored object has **no** `k8s:enc:...` envelope prefix a real
`EncryptionConfiguration` would add — i.e. the data is plaintext protobuf, not encrypted.
The listed "plaintext leaks" are the real secret **key names** (`DATABASE_URL`,
`INTERNAL_API_TOKEN`, etc.) appearing verbatim in the raw etcd bytes, which is exactly
what plaintext-at-rest looks like.

**2026-08-20 re-verification (this session, `kind-xaas`):** `scripts/enable-etcd-encryption.sh`
was actually run against the live `xaas-control-plane` container. It generated a real
AES-256 key via `openssl rand -base64 32`, wrote a real `EncryptionConfiguration`
(`apiserver.config.k8s.io/v1`, `aescbc` provider) to
`/etc/kubernetes/pki/encryption/encryption-config.yaml` inside the control-plane container
(mode 600), patched the live `/etc/kubernetes/manifests/kube-apiserver.yaml` static pod
manifest to add `--encryption-provider-config=...`, waited for kubelet's static-pod
controller to restart `kube-apiserver` (confirmed `Running` again), then re-wrote every
existing Secret through the API (`kubectl get secrets --all-namespaces -o json | kubectl
replace -f -`) so the two pre-existing, previously-plaintext Secrets
(`default/xaas-secrets`, `kube-system/bootstrap-token-abcdef`) were re-saved as real
`aescbc` ciphertext rather than left in their original plaintext form.

Re-ran `scripts/verify-etcd-encryption.sh default xaas-secrets` afterward — real output:

```
==> raw etcd bytes for /registry/secrets/default/xaas-secrets
00000000: 2f72 6567 6973 7472 792f 7365 6372 6574  /registry/secret
00000010: 732f 6465 6661 756c 742f 7861 6173 2d73  s/default/xaas-s
00000020: 6563 7265 7473 0a6b 3873 3a65 6e63 3a61  ecrets.k8s:enc:a
00000030: 6573 6362 633a 7631 3a6b 6579 313a 903d  escbc:v1:key1:.=
00000040: dda6 4e3e c90e adf1 8503 e370 c514 8a3f  ..N>.......p...?

envelope prefix present: True
plaintext leaks found:   none
RESULT: CIPHERTEXT CONFIRMED
```

Envelope prefix (`k8s:enc:aescbc:v1:key1:`) is now present and none of the decoded secret
key names/values from the live API (`DATABASE_URL`, `INTERNAL_API_TOKEN`,
`ONETIME_REVOKE_KEY`, `POSTGRES_PASSWORD`, `SECRET_KEY_BASE`) appear anywhere in the raw
etcd bytes. This is real, static-key `aescbc` envelope encryption (no third-party KMS
plugin), disclosed as such by the script's own header comment — not a rotating remote KMS.

Post-change cluster health check: `kubectl get pods -A` showed all pods `Running`/`Ready`
after the apiserver restart settled, except `kube-scheduler-xaas-control-plane` which was
already intermittently failing its readiness probe (`connection refused` / HTTP 500 on
`/readyz`) for 150+ minutes *before* this change per its own event history (`x98 over
150m`) — pre-existing flakiness on this cluster, not caused by the encryption-config
change or the apiserver restart it triggered. The `xaas` app itself was confirmed
real-reachable afterward: `kubectl port-forward svc/xaas 4000:4000` + `curl` returned
`http_status=200`.

### 4. NetworkPolicy — APPLIED and CONFIRMED ENFORCED on kind-xaas (2026-08-20 update)

**2026-08-20 re-verification (this session, `kind-xaas`, `kind v0.30.0`, kindnet only
CNI pod present — `kubectl get pods -n kube-system` showed no calico-node/cilium, only
`kindnet-sxpff`):** the file's original disclosed caveat ("kindnet does not enforce
NetworkPolicy") is **no longer accurate for this cluster** — real, repeated before/after
testing shows kindnet on this `kind v0.30.0` cluster DOES enforce NetworkPolicy.

Real test performed: from the live `xaas` pod, `curl -sv --max-time 3
telnet://prometheus:9090` (a path the applied policy's default-deny should block, since
no allow rule permits xaas -> prometheus):

- **Before applying** `k8s/network-policy.yaml`: `Connected to prometheus ... port 9090`
  (TCP handshake succeeds).
- **After applying**: `Connection timed out after 3001 milliseconds` (TCP handshake
  blocked) — reproduced 3x consecutively, then reconfirmed by removing the policy again
  (`Connected...` returns) and reapplying (`timed out` again).
- The policy's intended-allowed path (`xaas` -> `postgres:5432`) stayed reachable both
  before and after, as expected (`xaas-allow-egress-postgres` rule).

The manifest is now **applied** on `kind-xaas` (`kubectl apply -f
k8s/network-policy.yaml`; all 5 NetworkPolicy objects created:
`xaas-default-deny`, `xaas-allow-ingress-http`, `xaas-allow-egress-postgres`,
`xaas-allow-egress-dns`, `postgres-allow-ingress-from-xaas`).

Originally (this finding as first written): `kubectl get networkpolicy -A` returned no
resources — the file existed but was unapplied, and its header asserted kindnet does not
enforce NetworkPolicy (UNVERIFIED at the time, taken from the file rather than
independently checked). That specific sub-claim has now been checked directly against
this cluster's live behavior and found **not currently true** — kind's kindnet
implementation evidently gained real NetworkPolicy enforcement at some point before/at
`kind v0.30.0`, contradicting the file's original disclosure. `k8s/network-policy.yaml`'s
own header comment has been updated to reflect this real, current result.

### 5. No ResourceQuotas enforced — CONFIRMED (LOW)

```
$ kubectl get resourcequota -A
No resources found
```

`k8s/resource-quotas.yaml` exists but is unapplied. Given finding 1 (postgres/prometheus
have no resource limits at all, live), an unbounded namespace plus missing per-container
limits is a real double gap: a runaway `postgres` or `prometheus` container today has no
container-level ceiling and no namespace-level ceiling either.

## What each existing-but-unapplied manifest would close

| File | Closes |
|---|---|
| `k8s/rbac.yaml` | Finding 2 — gives `xaas` pods their own `xaas` ServiceAccount scoped to `get` on exactly `xaas-config`/`xaas-secrets`, off the shared `default` SA. Does not touch `postgres`/`prometheus`, which would still run as `default`. |
| `k8s/network-policy.yaml` | Finding 4 — default-deny + scoped allows for `app: xaas`. **Applied and confirmed enforced on kind-xaas as of 2026-08-20** (kindnet on `kind v0.30.0` does enforce NetworkPolicy — see finding 4's updated real before/after test; supersedes the file's original disclosed caveat that kindnet doesn't enforce it). |
| `k8s/resource-quotas.yaml` | Finding 5 (namespace-level) — does not add missing per-container limits to `postgres.yaml`/`prometheus.yaml` themselves (finding 1's resource half), only bounds the namespace total. |
| `scripts/enable-etcd-encryption.sh` | Finding 3 — not a manifest, a cluster-config script; adds a real `EncryptionConfiguration` to the kind control-plane's apiserver. **Run and confirmed on kind-xaas as of 2026-08-20** — see finding 3's updated real before/after verification. |
| *(none exists yet)* | Finding 1's securityContext half (runAsNonRoot, allowPrivilegeEscalation, readOnlyRootFilesystem, seccompProfile) — no manifest in `k8s/` currently adds `securityContext` blocks to `deployment.yaml`, `postgres.yaml`, or `prometheus.yaml`. This is a real, undocumented gap: none of the existing hardening files address it. |

## Summary of severities (trivy misconfig scan)

| Namespace/Resource | CRITICAL | HIGH | MEDIUM | LOW |
|---|---|---|---|---|
| ConfigMap/xaas-config | 0 | 0 | 1 | 0 |
| Deployment/postgres | 0 | 3 | 3 | 11 |
| Deployment/prometheus | 0 | 3 | 4 | 11 |
| Deployment/xaas | 0 | 3 | 3 | 7 |
| RBAC assessment (cluster-wide) | 0 | 0 | 0 | 0 |
| Infra assessment (cluster-wide) | 0 | 0 | 0 | 0 |

No CRITICAL findings. The HIGH findings are all variants of "no securityContext /
runs with default (root-capable) security context" across all three workloads, plus etcd
storing secrets unencrypted (found via the dedicated etcd script, not trivy — trivy's
scan here was workload-config-only, not etcd-at-rest).

## Explicitly not done in this task

- No manifest in `k8s/` was applied to the live cluster (`kubectl apply` was not run).
- No securityContext patch was applied live to any Deployment.

`scripts/enable-etcd-encryption.sh` **was** run in a later session (2026-08-20) — see
finding 3's updated real before/after verification above; this line is left as the
original scan's scope note, superseded by that update.

## See Also

- `docs/claude/diataxis/explanation/architecture-overview.md` — whole-system map this doc is one narrow piece of
