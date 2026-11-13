package main

import rego.v1

# =============================================================================
# Organization Baseline Policies (`policies/org_baseline.rego`)
# Enforces cross-field invariants on `config/org.yaml`
# =============================================================================

# Guardrail 1: Default minimum reviewers must be between 2 and 5
deny contains msg if {
	input.organization
	count_val := input.repository_defaults.min_reviewers
	count_val < 2
	msg := sprintf(
		"[ORG-BASELINE-001] repository_defaults.min_reviewers is set to %d, which violates the Tier 1 four-eyes baseline (minimum allowed is 2).",
		[count_val],
	)
}

deny contains msg if {
	input.organization
	count_val := input.repository_defaults.min_reviewers
	count_val > 5
	msg := sprintf(
		"[ORG-BASELINE-002] repository_defaults.min_reviewers is set to %d, which exceeds the maximum bound of 5.",
		[count_val],
	)
}

# Guardrail 2: At least one merge strategy must be enabled in repository_defaults
deny contains msg if {
	input.organization
	merges := input.repository_defaults.allowed_merge_types
	not merges.squash
	not merges.no_fast_forward
	not merges.rebase
	not merges.rebase_merge
	msg := "[ORG-BASELINE-003] repository_defaults.allowed_merge_types must enable at least one merge strategy (e.g., squash: true or no_fast_forward: true)."
}

# Guardrail 3: Pipeline job timeout must be within 15..180 minutes
deny contains msg if {
	input.organization
	timeout := input.pipeline_dials.default_job_timeout_minutes
	timeout < 15
	msg := sprintf(
		"[ORG-BASELINE-004] pipeline_dials.default_job_timeout_minutes (%d) cannot be less than 15 minutes.",
		[timeout],
	)
}

deny contains msg if {
	input.organization
	timeout := input.pipeline_dials.default_job_timeout_minutes
	timeout > 180
	msg := sprintf(
		"[ORG-BASELINE-005] pipeline_dials.default_job_timeout_minutes (%d) cannot exceed 180 minutes.",
		[timeout],
	)
}

# Guardrail 4: Agent pools must not auto-provision across all projects by default
warn contains msg if {
	input.organization
	some pool in input.agent_pools
	pool.auto_provision == true
	msg := sprintf(
		"[ORG-BASELINE-WARN-001] Agent pool '%s' has auto_provision=true. Consider setting auto_provision=false and granting queue access per project for least privilege.",
		[pool.name],
	)
}
