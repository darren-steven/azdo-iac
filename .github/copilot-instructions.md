# GitHub Copilot Instructions (`AzDo-IaC`)

This repository manages an Azure DevOps (AzDO) Organization using **OpenTofu** and a declarative **YAML Configuration Layer (`config/`)** governed by strict security baselines.

> **Canonical Source of Truth**: Always read and follow [AGENTS.md](../AGENTS.md) at the repository root. This repository is engineered for cross-agent compatibility between **GitHub Copilot** and **Google Gemini (Antigravity)**.

## Quick Reference Rules for GitHub Copilot

1. **Respect the Three-Tier Governance Model**:
   - **Tier 1 (Immutable Baseline)**: Hardcoded inside `modules/` and enforced by `policies/*.rego`. Cannot be disabled via YAML dials (e.g., private-only projects, blocking PR reviews on default branches, no self-approval, classic pipelines disabled, Key Vault-linked secret variable groups).
   - **Tier 2 (Bounded Dials)**: Configurable inside `config/*.yaml` within strict bounds enforced by `schemas/*.schema.json` and HCL `validation {}` blocks (e.g., `min_reviewers` between `2` and `5`).
   - **Tier 3 (Self-Service Catalogs)**: Onboarding projects (`config/projects/*.yaml`) and org groups (`config/groups.yaml`) using pre-hardened archetypes.

2. **Never Weaken the Engine to Satisfy a Dial Request**:
   - If a user asks to change a project or org setting, only modify `config/*.yaml`.
   - If the requested setting violates `schemas/*.schema.json` or `policies/*.rego`, **do not edit `modules/`, `schemas/`, or `policies/`** to bypass the error unless the user explicitly asks to perform a Platform Baseline modification. Explain the baseline constraint and offer the closest compliant dial value.

3. **Zero Secrets in Code**:
   - Never commit PATs, client secrets, or raw credentials in YAML or HCL.

4. **Mandatory Validation**:
   - Always run `./scripts/validate.sh` after editing any YAML, JSON Schema, Rego policy, or OpenTofu file.

5. **Available Agent Skills (`.agents/skills/`)**:
   - Both GitHub Copilot's new agent runtime and Gemini natively load Agent Skills from `.agents/skills/<skill-name>/SKILL.md` (supporting both automatic model invocation and manual `/skill-name` slash invocation; do not use legacy `.github/prompts/*.prompt.md` files):
     - `/adjust-org-dial` -> `.agents/skills/adjust-org-dial/SKILL.md`
     - `/onboard-project` -> `.agents/skills/onboard-project/SKILL.md`
     - `/create-baseline-dial` -> `.agents/skills/create-baseline-dial/SKILL.md`
     - `/author-azdo-module` -> `.agents/skills/author-azdo-module/SKILL.md`
     - `/explain-policy-failure` -> `.agents/skills/explain-policy-failure/SKILL.md`
