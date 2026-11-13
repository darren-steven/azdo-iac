---
applyTo: "config/**/*.yaml"
---

# Maintainer Rules for Editing Configuration Dials (`config/**/*.yaml`)

When assisting a user with files under `config/`, follow the canonical rules in [config/AGENTS.md](../../config/AGENTS.md) and the workflow in [.agents/skills/adjust-org-dial/SKILL.md](../../.agents/skills/adjust-org-dial/SKILL.md):

1. **Check the JSON Schema First**:
   - `config/org.yaml` is validated by `schemas/org.schema.json`.
   - `config/groups.yaml` is validated by `schemas/groups.schema.json`.
   - `config/projects/*.yaml` is validated by `schemas/project.schema.json`.
2. **Preserve the Schema Header**:
   - Always keep the `# yaml-language-server: $schema=...` header on line 1 of every YAML file in `config/`.
3. **Stay Within Allowed Bounds**:
   - Do not add undocumented keys or out-of-range values.
   - Never modify `modules/`, `schemas/`, or `policies/` to make an non-compliant YAML edit pass validation.
4. **State Blast Radius & Validate**:
   - State whether the change affects a single project or the entire Azure DevOps organization.
   - Run `./scripts/validate.sh` to verify schema and policy compliance.
