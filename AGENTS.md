# AI Agent Guardrails & Operating Rules (`AzDo-IaC`)

Welcome to the **Azure DevOps Organization Infrastructure-as-Code (`AzDo-IaC`)** repository.
This file (`AGENTS.md`) is the **canonical source of truth** for AI assistants operating in this repository, including **Google Gemini (Antigravity / Gemini CLI)** and **GitHub Copilot (VS Code / Coding Agent)**.

---

## 1. Core Architectural Philosophy: "Hardened Engine, Simple Dials"

This repository manages an Azure DevOps (AzDO) Organization using **OpenTofu** (`microsoft/azuredevops` and `Mastercard/restapi` providers) driven by a declarative **YAML Configuration Layer** (`config/`).

To support maintainers of varying skill levels safely, all settings are divided into three strict tiers:

1. **Tier 1 — Immutable Baseline (Locked in `modules/` & `policies/`)**:
   - Mandatory organization security and governance invariants enforced by code.
   - Examples: No public projects (`visibility = "private"`), no anonymous access, classic build/release pipelines disabled by default, mandatory blocking pull request reviews on default branches, no self-approval on PRs, and no plain-text secrets in variable groups.
   - **No YAML dial exists to disable Tier 1 controls.**
2. **Tier 2 — Bounded Dials (Exposed in `config/*.yaml`, Constrained by `schemas/` & HCL `validation`)**:
   - Safe configuration parameters that maintainers can tune within approved boundaries.
   - Examples: `min_reviewers` (`2` to `5`), `build_validation_expiry_hours` (`12` to `72`), `default_job_timeout_minutes` (`15` to `180`), merge strategy toggles (`allow_squash_merge`, `allow_no_fast_forward`).
3. **Tier 3 — Self-Service Catalogs (Exposed in `config/projects/*.yaml` & `config/groups.yaml`)**:
   - Declarative onboarding of projects (using pre-hardened archetypes: `standard-microservice`, `regulated-workload`, `sandbox`), teams, repositories, environments, and Key Vault-backed variable groups.

---

## 2. Non-Negotiable AI Guardrails

### Guardrail 1: Never Weaken the Engine to Satisfy a Dial Request
- When a user asks to configure a project, team, repository, or org setting, treat it as a **Maintainer task** targeting `config/*.yaml`.
- **NEVER** modify `modules/`, `schemas/`, or `policies/` to bypass a validation error, lower a minimum security bound (e.g., changing `min_reviewers >= 2` to `>= 1`), or disable a Tier 1 baseline control unless the user **explicitly** states they are performing a **Platform Baseline Change** and confirms the security trade-off.
- If a user asks for a setting that violates a Tier 1 invariant or Tier 2 bound (for example, *"make this project public"* or *"set minimum reviewers to 1"*), **stop and explain**:
  1. Which baseline invariant or dial bound blocks the request.
  2. Why the invariant exists.
  3. The closest compliant configuration available in `config/`.

### Guardrail 2: Zero Secrets & Zero Hardcoded Credentials
- Never write Personal Access Tokens (PATs), Entra ID client secrets, service connection passwords, or raw secret values into `.yaml`, `.tf`, `.tfvars`, or shell scripts.
- All pipeline and provider authentication must rely on environment variables (`AZDO_ORG_SERVICE_URL`, `AZDO_PERSONAL_ACCESS_TOKEN` or Entra ID OIDC token exchange in CI).
- Any AzDO Variable Group holding sensitive values must link to an Azure Key Vault (`key_vault` block) rather than storing inline variables.

### Guardrail 3: Explicit Blast-Radius Reporting
- Before finalizing any change to `config/org.yaml`, `config/groups.yaml`, or `modules/`, explicitly state the **Blast Radius** in your response:
  - **Scope**: Single repository, single project, or organization-wide.
  - **Resource Impact**: In-place update vs. destructive replacement (`destroy` / `create`).
  - **Approval Requirement**: Whether the modified path requires **Platform Admin** approval (`modules/`, `policies/`, `schemas/`, `.agents/`, `.github/`) or **Maintainer** approval (`config/`).

### Guardrail 4: Mandatory Verification Loop
- After making any change to `config/`, `schemas/`, `policies/`, `modules/`, or `environments/`, you **must** run `./scripts/validate.sh` before declaring the task complete.
- Never claim a configuration is valid until JSON Schema validation, policy checks, and OpenTofu checks pass.

---

## 3. Repository Navigation & Persona Boundaries

| Directory / Path | Primary Persona | Allowed Routine Operations | Restricted Operations |
| :--- | :--- | :--- | :--- |
| `config/` | **All Maintainers** | Edit org dials (`config/org.yaml`), groups (`config/groups.yaml`), and project definitions (`config/projects/*.yaml`). | Adding undocumented keys not present in `schemas/*.schema.json`. |
| `schemas/` | **Platform Engineers** | Add or update JSON Schema definitions when exposing a new bounded dial. | Relaxing `minimum`/`maximum`/`enum` security bounds without updating `policies/` and `modules/`. |
| `policies/` | **Platform Engineers** | Add or update OPA/Conftest Rego policies enforcing org baseline rules. | Deleting or weakening `deny` rules to silence failing checks. |
| `modules/` | **Platform Engineers** | Evolve OpenTofu modules (`org-baseline`, `project-archetype`, `org-settings-api-bridge`, `security-namespaces`). | Hardcoding org-specific names or removing `validation {}` blocks. |
| `environments/` | **Platform Engineers** | Wire root OpenTofu configurations (`yamldecode()` loading + module orchestration). | Placing raw resource blocks outside reusable modules. |
| `.agents/skills/` | **Platform Engineers** | Author canonical AI skills (`SKILL.md`) shared across Gemini and GitHub Copilot. | Creating legacy `.github/prompts/*.prompt.md` files or tool-specific instructions that drift. |

---

## 4. Available AI Skills & Workflows

Both **Google Gemini (Antigravity)** and **GitHub Copilot's new agent runtime** natively discover Agent Skills (`SKILL.md`) in `.agents/skills/` (supporting both automatic model invocation and manual `/<skill-name>` slash invocation):

1. **[adjust-org-dial](.agents/skills/adjust-org-dial/SKILL.md)**: Safely inspect and modify an exposed organization or project dial in `config/` within schema bounds.
2. **[onboard-project](.agents/skills/onboard-project/SKILL.md)**: Scaffold a new Azure DevOps project, teams, repositories, and environments using an approved archetype.
3. **[create-baseline-dial](.agents/skills/create-baseline-dial/SKILL.md)**: End-to-end platform engineering workflow to expose a new bounded dial across HCL, JSON Schema, OPA policy, and documentation.
4. **[author-azdo-module](.agents/skills/author-azdo-module/SKILL.md)**: Standards for authoring OpenTofu modules with `microsoft/azuredevops`, security namespace bitmasks, and the AzDO REST API bridge.
5. **[explain-policy-failure](.agents/skills/explain-policy-failure/SKILL.md)**: Run `./scripts/validate.sh`, translate schema/OPA/OpenTofu errors into plain language, and guide maintainers to a compliant fix.
