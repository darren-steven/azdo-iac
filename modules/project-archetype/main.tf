# =============================================================================
# Module: project-archetype (Core Project, Teams, Permissions & Environments)
# =============================================================================

module "security_constants" {
  source = "../security-namespaces"
}

locals {
  teams_by_name = { for t in var.teams : t.name => t }

  # Explicit repositories declared in YAML
  explicit_repos_by_name = { for r in var.repositories : r.name => r }

  # Combined map of all governed repositories (including the default '<project_name>'
  # repository when create_default_repository = true) so branch policies and
  # team permissions apply uniformly to all of them.
  repos_by_name = merge(
    local.explicit_repos_by_name,
    var.create_default_repository ? {
      (var.project_name) = {
        name                           = var.project_name
        default_branch                 = "refs/heads/main"
        build_validation_pipeline_name = null
        path_reviewers                 = []
      }
    } : {}
  )

  environments_by_name = { for e in var.environments : e.name => e }
  var_groups_by_name   = { for vg in var.variable_groups : vg.name => vg }

  # Enforce regulated-workload archetype floor (>= 3 reviewers, <= 12h expiry)
  effective_min_reviewers = (
    var.archetype == "regulated-workload"
    ? max(3, var.branch_policy_dials.min_reviewers)
    : var.branch_policy_dials.min_reviewers
  )
  effective_build_expiry_minutes = (
    var.archetype == "regulated-workload"
    ? min(12, var.branch_policy_dials.build_validation_expiry_hours) * 60
    : var.branch_policy_dials.build_validation_expiry_hours * 60
  )

  # Flatten team x repository permission pairs
  team_repo_permissions = merge([
    for team_name, team in local.teams_by_name : {
      for repo_name, repo in local.repos_by_name :
      "${team_name}::${repo_name}" => {
        team_name = team_name
        repo_name = repo_name
        role      = team.role
      }
    }
  ]...)
}

# -----------------------------------------------------------------------------
# 1. Project & Pipeline Security Settings (Tier 1 Private Visibility Hardcoded)
# -----------------------------------------------------------------------------
resource "azuredevops_project" "this" {
  name               = var.project_name
  description        = "[Archetype: ${var.archetype}] ${var.description}"
  visibility         = "private" # TIER 1 IMMUTABLE BASELINE: Always private
  version_control    = "Git"     # TIER 1 IMMUTABLE BASELINE: Always Git
  work_item_template = var.process_template

  features = {
    boards       = var.features.boards
    repositories = var.features.repositories
    pipelines    = var.features.pipelines
    testplans    = var.features.testplans
    artifacts    = var.features.artifacts
  }
}

resource "azuredevops_project_pipeline_settings" "this" {
  project_id = azuredevops_project.this.id

  enforce_job_scope                    = var.pipeline_dials.enforce_job_auth_scope_to_project
  enforce_job_scope_for_release        = true # TIER 1 IMMUTABLE BASELINE
  enforce_referenced_repo_scoped_token = var.pipeline_dials.enforce_referenced_repo_scoped_token
  enforce_settable_var                 = var.pipeline_dials.enforce_settable_var_at_queue
  publish_pipeline_metadata            = var.pipeline_dials.publish_pipeline_metadata
  status_badges_are_private            = true # TIER 1 IMMUTABLE BASELINE: Never expose public badges
}

# -----------------------------------------------------------------------------
# 2. Teams & Least-Privilege Repository Permissions
# -----------------------------------------------------------------------------
resource "azuredevops_team" "teams" {
  for_each = local.teams_by_name

  project_id  = azuredevops_project.this.id
  name        = each.value.name
  description = each.value.description
}

# Step 2a: Create explicit repositories declared in YAML first (ensures at least
# one repository exists in the project before deleting Azure DevOps's unmanaged default stub).
resource "azuredevops_git_repository" "repos" {
  for_each = local.explicit_repos_by_name

  project_id     = azuredevops_project.this.id
  name           = each.value.name
  default_branch = each.value.default_branch

  initialization {
    init_type = "Clean"
  }
}

# Step 2b: Reconcile the project's default '<project_name>' repository:
# - When create_default_repository = false: deletes the unmanaged '<project_name>' repository.
# - When create_default_repository = true: adopts the existing '<project_name>' repository in-place
#   (or creates it if previously deleted) and initializes refs/heads/main if empty.
resource "terraform_data" "reconcile_default_repository" {
  depends_on = [azuredevops_git_repository.repos]

  triggers_replace = [
    azuredevops_project.this.id,
    var.project_name,
    tostring(var.create_default_repository)
  ]

  provisioner "local-exec" {
    command = <<-EOT
      python3 - "${var.org_service_url}" "${azuredevops_project.this.id}" "${var.project_name}" "${tostring(var.create_default_repository)}" <<'PYEOF'
import base64, json, os, sys, time, urllib.error, urllib.request

org_url = sys.argv[1].rstrip("/")
project_id = sys.argv[2]
project_name = sys.argv[3]
create_default = sys.argv[4].lower() == "true"

token = os.environ.get("AZDO_PERSONAL_ACCESS_TOKEN", "")
if not token:
    sys.exit(0)

auth_hdr = f"Bearer {token}" if token.startswith("eyJ") else "Basic " + base64.b64encode(f":{token}".encode()).decode()
headers = {"Authorization": auth_hdr, "Content-Type": "application/json"}

def api_call(url, method="GET", payload=None):
    data = json.dumps(payload).encode("utf-8") if payload is not None else None
    req = urllib.request.Request(url, data=data, headers=headers, method=method)
    with urllib.request.urlopen(req) as resp:
        raw = resp.read().decode("utf-8")
        return json.loads(raw) if raw else {}

repos_url = f"{org_url}/{project_id}/_apis/git/repositories?api-version=7.1"
repos = api_call(repos_url).get("value", [])
default_repo = next((r for r in repos if r.get("name") == project_name), None)

if not create_default:
    if default_repo:
        del_url = f"{org_url}/{project_id}/_apis/git/repositories/{default_repo['id']}?api-version=7.1"
        api_call(del_url, method="DELETE")
        print(f"Deleted unmanaged default repository '{project_name}' ({default_repo['id']})")
    sys.exit(0)

# create_default is True: Adopt existing repo in-place or create it if previously deleted
if not default_repo:
    default_repo = api_call(
        repos_url,
        method="POST",
        payload={"name": project_name, "project": {"id": project_id}}
    )
    print(f"Created default repository '{project_name}' ({default_repo['id']})")
    time.sleep(2)

repo_id = default_repo["id"]
refs_url = f"{org_url}/{project_id}/_apis/git/repositories/{repo_id}/refs?filter=heads/main&api-version=7.1"
refs = api_call(refs_url).get("value", [])

if not refs:
    push_url = f"{org_url}/{project_id}/_apis/git/repositories/{repo_id}/pushes?api-version=7.1"
    push_payload = {
        "refUpdates": [
            {
                "name": "refs/heads/main",
                "oldObjectId": "0000000000000000000000000000000000000000"
            }
        ],
        "commits": [
            {
                "comment": "Initial commit (Managed by AzDo-IaC)",
                "changes": [
                    {
                        "changeType": "add",
                        "item": {"path": "/README.md"},
                        "newContent": {
                            "content": f"# {project_name}\n\nManaged by AzDo-IaC.\n",
                            "contentType": "rawtext"
                        }
                    }
                ]
            }
        ]
    }
    for attempt in range(5):
        try:
            api_call(push_url, method="POST", payload=push_payload)
            print(f"Initialized default repository '{project_name}' with refs/heads/main")
            break
        except urllib.error.HTTPError as e:
            if attempt < 4:
                time.sleep(2)
            else:
                err_body = e.read().decode("utf-8", errors="replace")
                print(f"Failed initializing '{project_name}': HTTP {e.code} - {err_body}", file=sys.stderr)
                sys.exit(1)
PYEOF
    EOT
  }
}

# Step 2c: When create_default_repository = true, look up the initialized '<project_name>'
# repository so OpenTofu attaches all branch policies and team permissions to it.
data "azuredevops_git_repository" "default_repo" {
  count      = var.create_default_repository ? 1 : 0
  depends_on = [terraform_data.reconcile_default_repository]

  project_id = azuredevops_project.this.id
  name       = var.project_name
}

locals {
  # Unified map of repository name -> repository ID across explicit + optional default repo
  all_managed_repo_ids = merge(
    { for k, r in azuredevops_git_repository.repos : k => r.id },
    var.create_default_repository ? { (var.project_name) = data.azuredevops_git_repository.default_repo[0].id } : {}
  )
}

resource "azuredevops_git_permissions" "team_repo_access" {
  for_each = local.team_repo_permissions

  project_id    = azuredevops_project.this.id
  repository_id = local.all_managed_repo_ids[each.value.repo_name]
  principal     = azuredevops_team.teams[each.value.team_name].descriptor
  replace       = false

  permissions = module.security_constants.git_role_permissions[each.value.role]
}

# -----------------------------------------------------------------------------
# 3. Environments & Production Approval Gates
# -----------------------------------------------------------------------------
resource "azuredevops_environment" "envs" {
  for_each = local.environments_by_name

  project_id  = azuredevops_project.this.id
  name        = each.value.name
  description = each.value.description
}

resource "azuredevops_check_approval" "env_approvals" {
  for_each = {
    for k, env in local.environments_by_name : k => env
    if env.require_approval && env.approver_team != null
  }

  project_id           = azuredevops_project.this.id
  target_resource_id   = azuredevops_environment.envs[each.key].id
  target_resource_type = "environment"

  requester_can_approve      = false # TIER 1 IMMUTABLE BASELINE: No self-approval on deployments
  minimum_required_approvers = 1
  timeout                    = 43200

  approvers = [
    azuredevops_team.teams[each.value.approver_team].id
  ]
}

# -----------------------------------------------------------------------------
# 4. Non-Secret Variable Groups (Secret groups require Key Vault linkage)
# -----------------------------------------------------------------------------
resource "azuredevops_variable_group" "plain_vars" {
  for_each = {
    for k, vg in local.var_groups_by_name : k => vg
    if vg.key_vault == null && length(vg.variables) > 0
  }

  project_id   = azuredevops_project.this.id
  name         = each.value.name
  description  = each.value.description
  allow_access = false # TIER 1 IMMUTABLE BASELINE: Must explicitly authorize per pipeline

  dynamic "variable" {
    for_each = each.value.variables
    content {
      name  = variable.key
      value = variable.value
    }
  }
}
