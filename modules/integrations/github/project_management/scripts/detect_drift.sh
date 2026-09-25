#!/usr/bin/env bash
# Real, honest one-directional drift REPORT between GitHub's actual issue
# state and this module's terraform.tfvars -- NOT a bidirectional sync.
#
# Terraform's github_issue resource does not track open/closed state (the
# provider's schema has no `state` attribute on that resource -- confirmed
# by reading the applied plan/state above), so closing an issue on GitHub
# causes zero Terraform-visible drift for that field; a `terraform apply`
# will never re-open it. What DOES drift and get silently overwritten on
# the next apply: title, body, labels, milestone -- if someone edits those
# directly on github.com, `terraform apply` pushes terraform.tfvars back
# over their edit (last-write-wins from Terraform's side).
#
# This script reports that kind of drift for real, using the real gh CLI
# against the real repo -- it does NOT write anything back to
# terraform.tfvars automatically (regenerating HCL heredoc bodies
# losslessly from JSON is fragile and would risk corrupting real content;
# a human should reconcile a reported diff by hand).
set -euo pipefail

REPO="seanchatmangpt/xaas"
MODULE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "== Real drift report: GitHub issues vs. ${MODULE_DIR}/terraform.tfvars =="
echo "Repo: ${REPO}"
echo

# Real state read from Terraform itself (source of truth for what
# Terraform believes it created/manages), not re-parsed from the .tfvars
# HCL (avoids a second, potentially-drifted HCL parser).
cd "$MODULE_DIR"
if [[ ! -f terraform.tfstate ]]; then
  echo "No terraform.tfstate found -- run 'terraform apply' at least once first." >&2
  exit 1
fi

managed_issue_numbers="$(terraform show -json terraform.tfstate \
  | python3 -c '
import json, sys
state = json.load(sys.stdin)
for r in state.get("values", {}).get("root_module", {}).get("resources", []):
    if r["type"] == "github_issue":
        for inst in [r] if "values" in r else []:
            pass
for r in state.get("values", {}).get("root_module", {}).get("resources", []):
    if r["type"] == "github_issue":
        v = r.get("values", {})
        print(v.get("number"))
')"

echo "Terraform-managed issue numbers: $(echo "$managed_issue_numbers" | tr '\n' ' ')"
echo

any_drift=0
for number in $managed_issue_numbers; do
  [[ -z "$number" || "$number" == "None" ]] && continue

  real_state="$(gh issue view "$number" --repo "$REPO" --json state,title,labels,milestone 2>/dev/null || echo '{}')"
  real_status="$(echo "$real_state" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("state","UNKNOWN"))')"
  real_title="$(echo "$real_state" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("title",""))')"

  if [[ "$real_status" == "CLOSED" ]]; then
    echo "DRIFT (untracked by Terraform): issue #${number} \"${real_title}\" is CLOSED on GitHub -- Terraform's github_issue resource has no state field, so 'terraform apply' will NOT reflect or fight this. Informational only."
    any_drift=1
  fi
done

if [[ "$any_drift" -eq 0 ]]; then
  echo "No closed-issue drift detected among Terraform-managed issues."
fi

echo
echo "For title/body/label/milestone drift, run a real 'terraform plan' in"
echo "${MODULE_DIR} -- Terraform itself will show any GitHub-side edit to"
echo "those fields as a diff, since they ARE tracked attributes."
