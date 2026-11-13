# OpenTofu Baseline Engine Rules (`modules/`)

You are operating inside `modules/`, which contains the **Protected OpenTofu Baseline Engine** for the Azure DevOps Organization.

## Rules for Authoring & Modifying Modules

1. **Enforce Tier 1 vs. Tier 2 Separation**:
   - **Tier 1 (Immutable Baseline)**: Security invariants that must never be overridden by maintainers (e.g., `visibility = "private"`, `blocking = true` on default branch policies, `submitter_can_vote = false`, `last_pusher_cannot_approve = true`) **must be hardcoded** in the resource block—do not expose them as module variables.
   - **Tier 2 (Bounded Dials)**: Any setting exposed as a variable in `variables.tf` **must** include at least one `validation {}` block enforcing its allowed range or enum values, with a clear, actionable `error_message`.
2. **OpenTofu & Provider Standards**:
   - Target **OpenTofu >= 1.8** (`microsoft/azuredevops >= 1.3.0` and `Mastercard/restapi >= 1.19.0`).
   - Always use `for_each` keyed by stable string identifiers (such as project key, repo name, or group name)—**never use `count` for collections** where items can be added or removed, as index shifts cause destructive resource recreation in Azure DevOps.
3. **AzDO Provider vs. REST API Bridge**:
   - Prefer native `azuredevops_*` resources whenever supported.
   - Use `modules/org-settings-api-bridge` only for organization-level policies or settings not supported by `microsoft/azuredevops` (see `.agents/skills/author-azdo-module/references/azdo-api-gaps.md`).
4. **Keep Dials Synchronized Across Layers**:
   - Whenever you add or modify an exposed variable in `modules/`, you must also update:
     - `environments/prod-org/main.tf` (wiring from `yamldecode()`)
     - `schemas/*.schema.json` (IDE schema validation)
     - `policies/*.rego` (OPA policy check)
     - `docs/dials-catalog.md` (human reference)
5. **Validate Before Completing**:
   - Run `./scripts/validate.sh` after any change in `modules/`.
