#!/usr/bin/env bash
# =============================================================================
# Unified Validation Harness (`scripts/validate.sh`)
# =============================================================================
# Runs the multi-layer guardrail checks for AzDo-IaC:
#   Layer 1: YAML Syntax & JSON Schema Validation (`schemas/*.schema.json`)
#   Layer 2: Baseline & Archetype Policy Gate (`policies/*.rego` + Python check)
#   Layer 3: OpenTofu Formatting & Structural Validation (`modules/`, `environments/`)
#   Layer 4: Cross-Agent AI Skill & Prompt Synchronization Check
# =============================================================================

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${REPO_ROOT}"

echo "============================================================================="
echo " AzDo-IaC Guardrails & Validation Suite"
echo "============================================================================="

# -----------------------------------------------------------------------------
# Layer 1 & 2: Schema Validation + Policy Invariant Gate (via Python 3)
# -----------------------------------------------------------------------------
echo ""
echo "[1/4] Validating YAML Configurations against JSON Schemas & Policy Guardrails..."

python3 - <<'PYEOF'
import json
import glob
import os
import re
import sys

try:
    import yaml
except ImportError:
    print("ERROR: python3-yaml (PyYAML) is required to parse config/*.yaml", file=sys.stderr)
    sys.exit(1)

errors = []
warnings = []

def load_json(path):
    with open(path, "r", encoding="utf-8") as f:
        return json.load(f)

def load_yaml(path):
    with open(path, "r", encoding="utf-8") as f:
        return yaml.safe_load(f)

def validate_against_schema(data, schema, path_prefix):
    """Lightweight recursive JSON Schema validator supporting Draft-07 constraints."""
    schema_type = schema.get("type")
    if schema_type == "object":
        if not isinstance(data, dict):
            errors.append(f"{path_prefix}: expected object, got {type(data).__name__}")
            return
        for req in schema.get("required", []):
            if req not in data:
                errors.append(f"{path_prefix}: missing required property '{req}'")
        props = schema.get("properties", {})
        add_props = schema.get("additionalProperties", True)
        for k, v in data.items():
            sub_path = f"{path_prefix}.{k}"
            if k in props:
                validate_against_schema(v, props[k], sub_path)
            elif add_props is False:
                errors.append(f"{path_prefix}: unknown/unsupported dial property '{k}' (not allowed by schema)")
            elif isinstance(add_props, dict):
                validate_against_schema(v, add_props, sub_path)
    elif schema_type == "array":
        if not isinstance(data, list):
            errors.append(f"{path_prefix}: expected array, got {type(data).__name__}")
            return
        min_items = schema.get("minItems")
        if min_items is not None and len(data) < min_items:
            errors.append(f"{path_prefix}: array must have at least {min_items} item(s)")
        item_schema = schema.get("items")
        if item_schema:
            for idx, item in enumerate(data):
                validate_against_schema(item, item_schema, f"{path_prefix}[{idx}]")
    elif schema_type == "integer":
        if not isinstance(data, int) or isinstance(data, bool):
            errors.append(f"{path_prefix}: expected integer, got {data!r}")
            return
        if "minimum" in schema and data < schema["minimum"]:
            errors.append(f"{path_prefix}: value {data} is below minimum allowed bound ({schema['minimum']})")
        if "maximum" in schema and data > schema["maximum"]:
            errors.append(f"{path_prefix}: value {data} exceeds maximum allowed bound ({schema['maximum']})")
    elif schema_type == "boolean":
        if not isinstance(data, bool):
            errors.append(f"{path_prefix}: expected boolean, got {data!r}")
    elif schema_type == "string":
        if not isinstance(data, str):
            errors.append(f"{path_prefix}: expected string, got {data!r}")
            return
        if "enum" in schema and data not in schema["enum"]:
            errors.append(f"{path_prefix}: value '{data}' must be one of {schema['enum']}")
        if "minLength" in schema and len(data) < schema["minLength"]:
            errors.append(f"{path_prefix}: string length ({len(data)}) is shorter than minLength ({schema['minLength']})")
        if "maxLength" in schema and len(data) > schema["maxLength"]:
            errors.append(f"{path_prefix}: string length ({len(data)}) exceeds maxLength ({schema['maxLength']})")
        if "pattern" in schema and not re.match(schema["pattern"], data):
            errors.append(f"{path_prefix}: value '{data}' does not match required pattern '{schema['pattern']}'")

# 1. Validate config/org.yaml
org_schema = load_json("schemas/org.schema.json")
org_data = load_yaml("config/org.yaml")
validate_against_schema(org_data, org_schema, "config/org.yaml")

# Check Org Baseline Policy Invariants (mirroring policies/org_baseline.rego)
if isinstance(org_data, dict) and "repository_defaults" in org_data:
    merges = org_data["repository_defaults"].get("allowed_merge_types", {})
    if not any(merges.get(k) for k in ("squash", "no_fast_forward", "rebase", "rebase_merge")):
        errors.append("[ORG-BASELINE-003] config/org.yaml: repository_defaults.allowed_merge_types must enable at least one merge strategy.")
for pool in org_data.get("agent_pools", []):
    if pool.get("auto_provision") is True:
        warnings.append(f"[ORG-BASELINE-WARN-001] config/org.yaml: agent pool '{pool.get('name')}' has auto_provision=true.")

# 2. Validate config/groups.yaml
groups_schema = load_json("schemas/groups.schema.json")
groups_data = load_yaml("config/groups.yaml")
validate_against_schema(groups_data, groups_schema, "config/groups.yaml")

# 3. Validate config/projects/*.yaml
project_schema = load_json("schemas/project.schema.json")
secret_keywords = ["SECRET", "PASSWORD", "PASSWD", "TOKEN", "API_KEY", "APIKEY", "PRIVATE_KEY", "CONNECTION_STRING", "CONN_STR", "CLIENT_SECRET", "PAT"]

project_files = sorted(glob.glob("config/projects/*.yaml"))
for pf in project_files:
    pdata = load_yaml(pf)
    validate_against_schema(pdata, project_schema, pf)
    proj = (pdata or {}).get("project", {})
    pkey = proj.get("key", "<unknown>")
    expected_filename = f"{pkey}.yaml"
    if os.path.basename(pf) != expected_filename:
        errors.append(f"[PROJ-KEY-MISMATCH] {pf}: project.key '{pkey}' must match filename '{ os.path.basename(pf) }'")

    archetype = proj.get("archetype")
    dials = proj.get("branch_policy_dials", {})
    if archetype == "regulated-workload":
        min_rev = dials.get("min_reviewers", 2)
        if min_rev < 3:
            errors.append(f"[PROJ-POLICY-001] {pf}: regulated-workload requires branch_policy_dials.min_reviewers >= 3 (got {min_rev})")
        expiry = dials.get("build_validation_expiry_hours", 24)
        if expiry > 12:
            errors.append(f"[PROJ-POLICY-002] {pf}: regulated-workload requires build_validation_expiry_hours <= 12 (got {expiry})")

    team_names = {t.get("name") for t in proj.get("teams", []) if isinstance(t, dict)}
    for env in proj.get("environments", []):
        ename = env.get("name", "")
        req_app = env.get("require_approval", False)
        approver = env.get("approver_team", "")
        if ename.lower() in {"prod", "production", "prd"} and req_app is not True:
            errors.append(f"[PROJ-POLICY-003] {pf}: production environment '{ename}' must set require_approval: true")
        if req_app is True and not approver:
            errors.append(f"[PROJ-POLICY-004] {pf}: environment '{ename}' requires approval and must set approver_team")
        if approver and approver not in team_names:
            errors.append(f"[PROJ-POLICY-005] {pf}: environment '{ename}' references unknown approver_team '{approver}'")

    for repo in proj.get("repositories", []):
        for pr in repo.get("path_reviewers", []):
            tname = pr.get("team_name", "")
            if tname not in team_names:
                errors.append(f"[PROJ-POLICY-006] {pf}: repo '{repo.get('name')}' path_reviewers references unknown team '{tname}'")

    if (proj.get("features") or {}).get("repositories") == "enabled":
        if not proj.get("create_default_repository", False) and len(proj.get("repositories") or []) == 0:
            errors.append(f"[PROJ-POLICY-008] {pf}: project with repositories enabled must either declare at least one repo in 'repositories' or set 'create_default_repository: true'")

    for vg in proj.get("variable_groups", []):
        for vkey in (vg.get("variables") or {}).keys():
            ukey = vkey.upper()
            for kw in secret_keywords:
                if kw in ukey:
                    errors.append(f"[PROJ-POLICY-007] {pf}: variable group '{vg.get('name')}' contains plain-text variable '{vkey}' matching secret keyword '{kw}'. Use a key_vault block instead.")

for w in warnings:
    print(f"  WARN: {w}")

if errors:
    for e in errors:
        print(f"  FAIL: {e}", file=sys.stderr)
    sys.exit(1)

print(f"  PASS: Validated config/org.yaml, config/groups.yaml, and {len(project_files)} project file(s).")
PYEOF

# -----------------------------------------------------------------------------
# Optional Conftest / OPA CLI Execution (if installed)
# -----------------------------------------------------------------------------
if command -v conftest >/dev/null 2>&1; then
  echo ""
  echo "[2/4] Running Conftest Rego Policies..."
  conftest test config/org.yaml -p policies/org_baseline.rego
  conftest test config/projects/*.yaml -p policies/project_guardrails.rego
else
  echo ""
  echo "[2/4] Conftest CLI not found on PATH (Rego rules verified via built-in policy engine in Step 1)."
fi

# -----------------------------------------------------------------------------
# Layer 3: OpenTofu / Terraform Structural & Format Check
# -----------------------------------------------------------------------------
echo ""
echo "[3/4] Checking OpenTofu / HCL Structure & Guardrails..."

if command -v tofu >/dev/null 2>&1; then
  tofu fmt -check -recursive modules/ environments/
  echo "  PASS: OpenTofu formatting check passed."
elif command -v terraform >/dev/null 2>&1; then
  terraform fmt -check -recursive modules/ environments/
  echo "  PASS: Terraform formatting check passed."
else
  echo "  INFO: 'tofu' binary not installed in current environment; running static HCL guardrail inspection..."
fi

# Static HCL Guardrail Inspection: Verify Tier 1 hardcoded invariants in modules/
python3 - <<'PYEOF'
import re
import sys

with open("modules/project-archetype/main.tf", "r", encoding="utf-8") as f:
    proj_main = f.read()

with open("modules/project-archetype/branch_policies.tf", "r", encoding="utf-8") as f:
    branch_pol = f.read()

with open("modules/org-settings-api-bridge/main.tf", "r", encoding="utf-8") as f:
    bridge_main = f.read()

checks = [
    (bool(re.search(r'visibility\s*=\s*"private"', proj_main)), "Tier 1 invariant: project visibility must remain hardcoded to 'private' in modules/project-archetype/main.tf"),
    (bool(re.search(r'submitter_can_vote\s*=\s*false', branch_pol)), "Tier 1 invariant: submitter_can_vote must remain hardcoded to false in modules/project-archetype/branch_policies.tf"),
    (bool(re.search(r'last_pusher_cannot_approve\s*=\s*true', branch_pol)), "Tier 1 invariant: last_pusher_cannot_approve must remain hardcoded to true in modules/project-archetype/branch_policies.tf"),
    (bool(re.search(r'"Policy\.AllowOrgPublicProjects"\s*=\s*false', bridge_main)), "Tier 1 invariant: Policy.AllowOrgPublicProjects must remain false in modules/org-settings-api-bridge/main.tf"),
    (bool(re.search(r'"Policy\.DisallowAnonymousAccess"\s*=\s*true', bridge_main)), "Tier 1 invariant: Policy.DisallowAnonymousAccess must remain true in modules/org-settings-api-bridge/main.tf"),
]

failed = False
for ok, desc in checks:
    if not ok:
        print(f"  FAIL: {desc}", file=sys.stderr)
        failed = True

if failed:
    sys.exit(1)
print("  PASS: All Tier 1 immutable baseline invariants verified in HCL modules.")
PYEOF

# -----------------------------------------------------------------------------
# Layer 4: Cross-Agent AI Skill & Guardrail Integrity Check (Gemini + Copilot)
# -----------------------------------------------------------------------------
echo ""
echo "[4/4] Verifying Unified Agent Skills (.agents/skills/) & Cross-Agent Guardrails..."

python3 - <<'PYEOF'
import glob
import os
import sys
import yaml

skill_files = sorted(glob.glob(".agents/skills/*/SKILL.md"))
if not skill_files:
    print("  FAIL: No canonical skills found in .agents/skills/*/SKILL.md", file=sys.stderr)
    sys.exit(1)

skills = []
for sf in skill_files:
    folder_name = os.path.basename(os.path.dirname(sf))
    with open(sf, "r", encoding="utf-8") as f:
        content = f.read()
    if not content.startswith("---"):
        print(f"  FAIL: {sf} is missing YAML frontmatter", file=sys.stderr)
        sys.exit(1)
    parts = content.split("---", 2)
    fm = yaml.safe_load(parts[1]) or {}
    if fm.get("name") != folder_name:
        print(f"  FAIL: {sf} frontmatter name '{fm.get('name')}' does not match folder '{folder_name}'", file=sys.stderr)
        sys.exit(1)
    if not fm.get("description"):
        print(f"  FAIL: {sf} is missing frontmatter description", file=sys.stderr)
        sys.exit(1)
    if fm.get("disable-model-invocation") is True:
        print(f"  FAIL: {sf} sets disable-model-invocation: true (breaks automatic skill loading)", file=sys.stderr)
        sys.exit(1)
    skills.append(folder_name)

legacy_prompts = glob.glob(".github/prompts/*.prompt.md")
if legacy_prompts:
    print(f"  FAIL: Found deprecated .github/prompts/*.prompt.md files ({legacy_prompts}). Use unified SKILL.md files instead.", file=sys.stderr)
    sys.exit(1)

for req_file in ["AGENTS.md", "GEMINI.md", "config/AGENTS.md", "modules/AGENTS.md", ".github/copilot-instructions.md"]:
    if not os.path.isfile(req_file):
        print(f"  FAIL: Missing required AI guardrail file: {req_file}", file=sys.stderr)
        sys.exit(1)

# Verify no hardcoded machine paths or file:// URIs exist in repository files
for root, dirs, files in os.walk("."):
    dirs[:] = [d for d in dirs if d not in {".git", ".terraform"}]
    for fn in files:
        if fn == "validate.sh":
            continue
        fpath = os.path.join(root, fn)
        try:
            with open(fpath, "r", encoding="utf-8") as f:
                text = f.read()
        except UnicodeDecodeError:
            continue
        for bad_pattern in ("file://", "/home/", "/Users/"):
            if bad_pattern in text:
                print(f"  FAIL: {fpath} contains hardcoded path pattern '{bad_pattern}'. Use repository-relative paths instead.", file=sys.stderr)
                sys.exit(1)

print(f"  PASS: {len(skills)} unified Agent Skills and relative paths validated for Gemini and GitHub Copilot: {', '.join(skills)}")
PYEOF

echo ""
echo "============================================================================="
echo " ALL GUARDRAIL & VALIDATION CHECKS PASSED"
echo "============================================================================="
