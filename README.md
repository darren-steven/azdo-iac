# Azure DevOps Organization IaC (`AzDo-IaC`)

Declarative **Infrastructure-as-Code (OpenTofu)** framework for governing an **Azure DevOps Organization** using a **"Hardened Baseline + Exposed Dials"** model, equipped with cross-agent AI skills and guardrails for **Google Gemini (Antigravity / Gemini CLI)** and **GitHub Copilot**.

---

## Architecture Overview

1. **Declarative Configuration Surface (`config/`)**:
   - Maintainers of all skill levels configure the organization (`config/org.yaml`), groups (`config/groups.yaml`), and projects (`config/projects/*.yaml`) via schema-validated YAML files.
2. **Multi-Layer Guardrails (`schemas/`, `policies/`, `scripts/validate.sh`)**:
   - Every change is verified against JSON Schemas (for real-time IDE autocomplete and bounds checking), OPA/Rego policy rules, and OpenTofu variable validations before reaching Azure DevOps.
3. **Protected OpenTofu Engine (`modules/`, `environments/`)**:
   - **Tier 1 Immutable Baselines** (such as private-only projects, blocking PR reviews on `main`, no self-approval, disabled classic pipelines, and Entra ID Conditional Access) are locked in HCL modules.
   - **Tier 2 Bounded Dials** (such as minimum reviewer count `2..5`, build validation expiration `12h..72h`, and merge strategy toggles) are exposed within safe bounds.
   - Includes a dedicated **REST API Bridge (`modules/org-settings-api-bridge`)** for Azure DevOps organization-level settings not natively supported by the `microsoft/azuredevops` provider.
4. **Cross-Agent AI Skills & Guardrails (`AGENTS.md`, `GEMINI.md`, `.agents/skills/`, `.github/`)**:
   - Synchronized instructions and skills ensure both Gemini and GitHub Copilot guide contributors safely and never weaken baseline modules to bypass policy errors.

---

## Quick Start

### 1. Validate Configuration & Guardrails Locally
```bash
./scripts/validate.sh
```

### 2. Common Maintainer Workflows
- **Adjust an Org or Project Dial**: Edit [config/org.yaml](./config/org.yaml) or `config/projects/<project>.yaml` (or use the `adjust-org-dial` AI skill).
- **Onboard a New Project**: Scaffold `config/projects/<project-key>.yaml` from [config/projects/example-service.yaml](./config/projects/example-service.yaml) (or use the `onboard-project` AI skill).

---

## Key Documentation & References

- **[AI Agent Guardrails (`AGENTS.md`)](./AGENTS.md)**: Canonical rules for Gemini and GitHub Copilot.
- **[Contributor & Maintainer Guide (`docs/onboarding-guide.md`)](./docs/onboarding-guide.md)**: Role-based onboarding and workflow instructions.
- **[Dials & Baselines Catalog (`docs/dials-catalog.md`)](./docs/dials-catalog.md)**: Full reference of Tier 1 locked baselines and Tier 2 bounded dials.
- **[AzDO Provider vs. REST API Matrix](./.agents/skills/author-azdo-module/references/azdo-api-gaps.md)**: Coverage reference for `microsoft/azuredevops` vs. `modules/org-settings-api-bridge`.
