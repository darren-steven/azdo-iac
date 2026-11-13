# Contributor & Maintainer Guide (`AzDo-IaC`)

This guide explains how to make changes safely in `AzDo-IaC`, regardless of your familiarity with OpenTofu/Terraform or Azure DevOps internals.

---

## 1. Which Role Are You Acting In?

| Role | What You Edit | What You Need to Know |
| :--- | :--- | :--- |
| **Maintainer / Contributor** | `config/projects/*.yaml`, `config/groups.yaml`, `config/org.yaml` | **YAML only.** You do not need to write OpenTofu/HCL. Your IDE and `./scripts/validate.sh` will automatically validate your changes against the organization's security bounds. |
| **Platform Engineer** | `modules/`, `schemas/`, `policies/`, `environments/`, `.agents/skills/` | **OpenTofu + JSON Schema + OPA Rego.** You maintain the baseline engine and expose bounded dials for maintainers. |

---

## 2. Using AI Assistants Safely (Google Gemini & GitHub Copilot)

This repository includes built-in AI skills and guardrails that work identically in **Google Gemini (Antigravity / Gemini CLI)** and **GitHub Copilot (VS Code / Coding Agent)**.

### Common Tasks & Prompts You Can Use

| Goal | Natural Language Prompt (Gemini / Copilot) | Copilot Slash Command |
| :--- | :--- | :--- |
| **Change a project or org setting** | *"Increase minimum reviewers for `example-service` to 3 and require squash merge only."* | `/adjust-org-dial` |
| **Onboard a new AzDO project** | *"Onboard a new `standard-microservice` project called `billing-engine` with `api` and `worker` repos."* | `/onboard-project` |
| **Understand why validation failed** | *"Explain why `./scripts/validate.sh` failed on my project YAML and show me how to fix it."* | `/explain-policy-failure` |
| **Expose a new dial (Platform Engineers)** | *"Expose a new bounded dial for PR status check timeout across schema, policy, and module."* | `/create-baseline-dial` |

> **Built-in Safety Net**: If you ask the AI for a setting that violates our security baseline (such as setting `min_reviewers: 1` or putting a secret in a plain-text variable group), the AI is instructed to explain the policy constraint and suggest a compliant option rather than modifying the underlying OpenTofu modules.

---

## 3. Step-by-Step: Onboarding a New Project

1. **Copy the example or ask your AI assistant**:
   - Copy [config/projects/example-service.yaml](../config/projects/example-service.yaml) to `config/projects/<your-project-key>.yaml` (the filename must match `project.key`).
2. **Choose your archetype**:
   - `standard-microservice`, `regulated-workload`, or `sandbox` (see [docs/dials-catalog.md](./dials-catalog.md)).
3. **Define teams, repositories, and environments**:
   - Any environment named `prod` or `production` must set `require_approval: true` and name an `approver_team` from your `teams` list.
   - Any secret variables must use a `key_vault` block referencing an Azure Key Vault and service connection—never commit raw secrets.
4. **Validate locally**:
   ```bash
   ./scripts/validate.sh
   ```
5. **Open a Pull Request**:
   - The CI pipeline will run `./scripts/validate.sh` and `tofu plan`, posting the planned Azure DevOps changes on your PR.
