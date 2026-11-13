# Configuration Dials Rules (`config/`)

You are operating inside `config/`, which is the **Declarative Maintainer Surface ("The Dials")** for the Azure DevOps Organization.

## Rules for Editing `config/*.yaml`

1. **Schema First**:
   - Before adding or modifying fields in `config/org.yaml`, check [org.schema.json](../schemas/org.schema.json).
   - Before adding or modifying fields in `config/projects/*.yaml`, check [project.schema.json](../schemas/project.schema.json).
   - Before adding or modifying fields in `config/groups.yaml`, check [groups.schema.json](../schemas/groups.schema.json).
2. **Preserve Schema Directive**:
   - Every YAML file in `config/` must keep its top-level `# yaml-language-server: $schema=...` comment so maintainers get instant IDE autocomplete and inline validation in VS Code / Antigravity IDE.
3. **Stay Within Bounded Dials (Tier 2)**:
   - Do not invent new YAML keys that do not exist in `schemas/`.
   - If a maintainer wants a setting outside the allowed bounds (e.g., `min_reviewers: 1`, `visibility: public`, or enabling classic pipelines), explain that the value is blocked by the organization baseline and offer the nearest compliant value.
   - **Never** edit `modules/`, `schemas/`, or `policies/` just to make an out-of-bounds YAML value pass validation.
4. **Validate Before Completing**:
   - Run `./scripts/validate.sh` after any edit in `config/`.
