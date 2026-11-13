---
applyTo: "modules/**/*.tf,environments/**/*.tf,policies/**/*.rego,schemas/**/*.json"
---

# Platform Engineering Rules for Core Engine & Guardrails

When assisting a user with files in `modules/`, `environments/`, `policies/`, or `schemas/`, follow the canonical rules in [modules/AGENTS.md](../../modules/AGENTS.md) and the skills in [.agents/skills/author-azdo-module/SKILL.md](../../.agents/skills/author-azdo-module/SKILL.md) and [.agents/skills/create-baseline-dial/SKILL.md](../../.agents/skills/create-baseline-dial/SKILL.md):

1. **Protect Tier 1 Baselines**:
   - Never expose Tier 1 security invariants (e.g., private project visibility, blocking PR policies on default branches, disallowing self-approval, disabling classic pipelines) as boolean toggles that could weaken the baseline.
2. **Enforce Validation on Every Tier 2 Variable**:
   - Every exposed variable in `modules/*/variables.tf` must include a `validation {}` block with an explicit `error_message` explaining the allowed range or enum values.
3. **Synchronize Across All 4 Layers**:
   - Any new or updated dial must be updated in lockstep across:
     1. `schemas/*.schema.json`
     2. `policies/*.rego`
     3. `modules/*` & `environments/prod-org/main.tf`
     4. `docs/dials-catalog.md`
4. **Use Stable Keys with `for_each`**:
   - Never use `count` for lists of projects, repositories, teams, or branch policies; always use `for_each` keyed by a unique string identifier.
5. **Run Validation**:
   - Always execute `./scripts/validate.sh` before finishing.
