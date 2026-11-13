package main

import rego.v1

# =============================================================================
# Project Guardrails (`policies/project_guardrails.rego`)
# Enforces archetype-specific invariants and anti-secret rules on `config/projects/*.yaml`
# =============================================================================

# Guardrail 1: Regulated workloads must require at least 3 reviewers and <= 12h build expiry
deny contains msg if {
	input.project.archetype == "regulated-workload"
	min_rev := object.get(object.get(input.project, "branch_policy_dials", {}), "min_reviewers", 2)
	min_rev < 3
	msg := sprintf(
		"[PROJ-POLICY-001] Project '%s' uses archetype 'regulated-workload' and must set branch_policy_dials.min_reviewers >= 3 (got %d).",
		[input.project.key, min_rev],
	)
}

deny contains msg if {
	input.project.archetype == "regulated-workload"
	expiry := object.get(object.get(input.project, "branch_policy_dials", {}), "build_validation_expiry_hours", 24)
	expiry > 12
	msg := sprintf(
		"[PROJ-POLICY-002] Project '%s' uses archetype 'regulated-workload' and must set branch_policy_dials.build_validation_expiry_hours <= 12 (got %d).",
		[input.project.key, expiry],
	)
}

# Guardrail 2: Production environments ('prod' or 'production') must require approval and specify an approver_team
deny contains msg if {
	some env in input.project.environments
	lower(env.name) in {"prod", "production", "prd"}
	env.require_approval != true
	msg := sprintf(
		"[PROJ-POLICY-003] Project '%s' environment '%s' is a production environment and must set require_approval: true.",
		[input.project.key, env.name],
	)
}

deny contains msg if {
	some env in input.project.environments
	env.require_approval == true
	approver := object.get(env, "approver_team", "")
	approver == ""
	msg := sprintf(
		"[PROJ-POLICY-004] Project '%s' environment '%s' has require_approval: true and must specify a valid approver_team.",
		[input.project.key, env.name],
	)
}

# Guardrail 3: Approver teams referenced in environments or path_reviewers must exist in project.teams
team_names contains t.name if {
	some t in input.project.teams
}

deny contains msg if {
	some env in input.project.environments
	approver := object.get(env, "approver_team", "")
	approver != ""
	not approver in team_names
	msg := sprintf(
		"[PROJ-POLICY-005] Project '%s' environment '%s' references approver_team '%s', which is not defined in project.teams.",
		[input.project.key, env.name, approver],
	)
}

deny contains msg if {
	some repo in input.project.repositories
	some pr in object.get(repo, "path_reviewers", [])
	not pr.team_name in team_names
	msg := sprintf(
		"[PROJ-POLICY-006] Project '%s' repository '%s' path_reviewers references team_name '%s', which is not defined in project.teams.",
		[input.project.key, repo.name, pr.team_name],
	)
}

# Guardrail 4: Reject plain-text variables that look like secrets or credentials
suspicious_secret_patterns := ["SECRET", "PASSWORD", "PASSWD", "TOKEN", "API_KEY", "APIKEY", "PRIVATE_KEY", "CONNECTION_STRING", "CONN_STR", "CLIENT_SECRET", "PAT"]

deny contains msg if {
	some vg in object.get(input.project, "variable_groups", [])
	some var_key, _ in object.get(vg, "variables", {})
	upper_key := upper(var_key)
	some pattern in suspicious_secret_patterns
	contains(upper_key, pattern)
	msg := sprintf(
		"[PROJ-POLICY-007] Project '%s' variable group '%s' defines plain-text variable '%s' matching sensitive keyword '%s'. Sensitive values must use a 'key_vault' block instead of inline 'variables'.",
		[input.project.key, vg.name, var_key, pattern],
	)
}

# Guardrail 5: When repositories feature is enabled, at least one governed repository must exist
deny contains msg if {
	input.project.features.repositories == "enabled"
	create_def := object.get(input.project, "create_default_repository", false)
	repos := object.get(input.project, "repositories", [])
	not create_def
	count(repos) == 0
	msg := sprintf(
		"[PROJ-POLICY-008] Project '%s' has repositories enabled and must either declare at least one repo in 'repositories' or set 'create_default_repository: true'.",
		[input.project.key],
	)
}
