#!/usr/bin/env bash
# =============================================================================
# Local OpenTofu Runner (`scripts/tofu-local.sh`)
# =============================================================================
# Authenticates to Azure DevOps using your active `az login` session (fetching
# a short-lived Entra ID token for Azure DevOps in memory—zero PATs on disk)
# and runs OpenTofu in `environments/prod-org`.
#
# Usage:
#   ./scripts/tofu-local.sh init
#   ./scripts/tofu-local.sh plan
#   ./scripts/tofu-local.sh apply
#   ./scripts/tofu-local.sh destroy
# =============================================================================

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${REPO_ROOT}"

if [[ $# -eq 0 ]]; then
  echo "Usage: ./scripts/tofu-local.sh <init|plan|apply|destroy|...> [args]"
  exit 1
fi

# 1. Run pre-flight guardrails & schema validation first
"${REPO_ROOT}/scripts/validate.sh"

# 2. Extract Organization URL from config/org.yaml
ORG_URL="$(python3 -c 'import yaml; print(yaml.safe_load(open("config/org.yaml"))["organization"]["service_url"])')"
ORG_NAME="$(python3 -c 'import yaml; print(yaml.safe_load(open("config/org.yaml"))["organization"]["name"])')"

if [[ "${ORG_NAME}" == "contoso-engineering" ]]; then
  echo ""
  echo "ERROR: config/org.yaml still has placeholder organization.name 'contoso-engineering'." >&2
  echo "Please update organization.name and organization.service_url in config/org.yaml to your Azure DevOps org first." >&2
  exit 1
fi

export AZDO_ORG_SERVICE_URL="${ORG_URL}"

# 3. Acquire short-lived Azure DevOps token from `az login` if AZDO_PERSONAL_ACCESS_TOKEN is not set
if [[ -z "${AZDO_PERSONAL_ACCESS_TOKEN:-}" ]]; then
  if ! command -v az >/dev/null 2>&1; then
    echo "ERROR: Azure CLI ('az') not found on PATH and AZDO_PERSONAL_ACCESS_TOKEN is not set." >&2
    exit 1
  fi
  echo ""
  echo "Acquiring short-lived Azure DevOps token from active 'az login' session for ${AZDO_ORG_SERVICE_URL}..."
  # 499b84ac-1321-427f-aa17-267ca6975798 is the canonical Microsoft Entra resource ID for Azure DevOps
  AZDO_PERSONAL_ACCESS_TOKEN="$(az account get-access-token --resource 499b84ac-1321-427f-aa17-267ca6975798 --query accessToken -o tsv)"
  export AZDO_PERSONAL_ACCESS_TOKEN
fi

# 4. Run OpenTofu inside environments/prod-org
cd "${REPO_ROOT}/environments/prod-org"
echo ""
echo "Running: tofu $* (Target Org: ${AZDO_ORG_SERVICE_URL})"
exec tofu "$@"
