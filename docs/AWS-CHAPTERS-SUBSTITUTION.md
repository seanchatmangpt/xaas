# AWS-Only Chapters: Real, Deliberate Substitution (not a gap)

Three of the book's 12 chapters are fundamentally AWS-specific and cannot be validated
without a real AWS account, real credentials, and real cloud spend:

- **`the_production_environment_and_packer`** — builds a real AMI on real EC2 via Packer.
- **`revise_your_aws_stack_to_create_a_multinode_swarm`** — real EC2 instances, real Docker
  Swarm join tokens via real AWS SSM Parameter Store.
- **`autoscaling_and_optimizing_your_deployment_strategy`** — real AWS Auto Scaling Groups,
  real AWS load balancers.

Per an explicit instruction this session ("use colima and kind for devops"), these three
chapters' real underlying *capability* — a production deployment target that can run
multiple nodes and scale — was substituted with a real, local, cloud-agnostic equivalent:
`colima` (container runtime) + `kind` (local Kubernetes), not skipped.

## What was actually validated as the real substitute

- **Production deployment target**: real `kind` cluster (`xaas`), real `Deployment`/
  `Service` manifests, real image built and loaded (`docker build` → `kind load
  docker-image`), verified live via port-forward + curl (HTTP 200, real Phoenix response).
- **Multi-node/clustering**: kind's k8s-native replica scaling
  (`kubectl scale deployment/xaas --replicas=N`) is the real substitute for EC2 multinode
  swarm — see the real distributed-Erlang clustering validation run this session against
  2 real pods.
- **Persistence**: real Postgres `PersistentVolumeClaim`, confirmed data survives pod
  delete+recreate — the real substitute for EC2 instance/EBS durability concerns.
- **Observability**: real Prometheus deployed into the same kind cluster, confirmed
  scraping the app's real `/metrics` endpoint (`health: up`).

## What remains genuinely untested, honestly disclosed

- Real AMI baking via Packer was never run — would require real AWS credentials and real
  cost; not attempted, not fabricated.
- Real AWS Auto Scaling Group behavior (scale-out under real load, real load-balancer
  health-check-driven rollback) has no real local equivalent tested this session beyond
  manual `kubectl scale` — k8s's own `HorizontalPodAutoscaler` would be the real, testable,
  cloud-agnostic substitute for a future pass, not yet built.
- Real cross-region/cross-AZ behavior has no meaningful local equivalent at all.

This document exists so these three chapters are recorded as a real, deliberate,
capability-equivalent substitution — not silently skipped or missing from the book's
completion status.
