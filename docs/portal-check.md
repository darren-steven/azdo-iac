Here is a tour of what you will see in **`https://dev.azure.com/tofutest`**, mapped to the **Tier 1 (Locked Baselines)** and **Tier 2/3 (YAML Dials)** that created them:

---

### 1. Organization-Level Settings (`https://dev.azure.com/tofutest/_settings/`)

* **Organization settings → Permissions (`/_settings/groups`)**
  * You will see the 4 governance groups defined in [config/groups.yaml](../config/groups.yaml):
    * **AzDO Platform Admins** (`[PLATFORM-ADMIN] ...`)
    * **AzDO Governance Maintainers** (`[MAINTAINER] ...`)
    * **AzDO Security Auditors** (`[AUDITOR] ...`)
    * **AzDO IaC Control Plane Automation** (`[SERVICE-PRINCIPAL-AUTOMATION] ...`)
* **Organization settings → Pipelines → Agent pools (`/_settings/agentpools`)**
  * You will see the 2 custom pools from [config/org.yaml](../config/org.yaml):
    * **`contoso-linux-mdp`** and **`contoso-regulated-mdp`** (with auto-provisioning across all projects turned **Off** for least privilege).

---

### 2. Project Overview & Feature Dials (`https://dev.azure.com/tofutest/Example%20Platform%20Service`)

Open the **`Example Platform Service`** project (configured via [config/projects/example-service.yaml](../config/projects/example-service.yaml)):

* **Left Navigation Sidebar**:
  * Notice **Test Plans** is completely hidden from the left menu because `features.testplans: "disabled"` is set in the project YAML, while **Boards**, **Repos**, **Pipelines**, and **Artifacts** are enabled.
* **Project settings → Overview**:
  * **Description**: Prefixed with `[Archetype: standard-microservice]`.
  * **Visibility**: **Private** *(Tier 1 Locked Baseline)*.
  * **Process**: **Agile**.
* **Project settings → Teams**:
  * You will see the 3 teams provisioned from YAML:
    * **`Example Service Developers`** (`contributor` role)
    * **`Example Service Maintainers`** (`lead` role)
    * **`Example Service Readers`** (`reader` role)

---

### 3. Pipeline Security Toggles (`Project settings → Pipelines → Settings`)

All 6 security switches are turned **On**:
* **Limit job authorization scope to current project for non-release pipelines**: **On** *(Dial)*
* **Limit job authorization scope to current project for release pipelines**: **On** *(Tier 1 Baseline)*
* **Protect access to repositories in YAML pipelines**: **On** *(Dial)*
* **Limit variables that can be set at queue time**: **On** *(Dial)*
* **Publish metadata from pipelines**: **On** *(Dial)*
* **Disable anonymous access to badges** (`status_badges_are_private`): **On** *(Tier 1 Baseline)*

---

### 4. Git Repositories, Permissions & Branch Policies (`Project settings → Repositories`)

You will see **`example-service-api`** and **`example-service-worker`**:

1. **Least-Privilege Git Permissions (`Select a repo → Security tab`)**:
   * Click on **`Example Service Developers`**, **`Example Service Maintainers`**, or **`Example Service Readers`**:
     * **Force push (rewrite history)**: Explicitly **Deny** across all teams *(Tier 1 Baseline)*.
     * **Edit policies**: Explicitly **Deny** across all teams *(Tier 1 Baseline — prevents click-ops tampering with branch policies)*.
     * **Delete repository / Manage permissions**: Explicitly **Deny**.
     * **Readers** only have `Read = Allow`; **Developers** add `Contribute`, `Create branch`, and `Contribute to pull requests`; **Maintainers** add `Create tag` and `Manage notes`.
2. **Branch Protection (`Select a repo → Policies tab → Branch Policies → main`)**:
   * **Require a minimum number of reviewers**: **On**
     * Minimum number of reviewers: **`2`** *(Tier 2 Dial)*
     * *Allow requestors to approve their own changes*: **Unchecked** *(Tier 1 Baseline)*
     * *Prohibit the most recent pusher from approving their own changes*: **Checked** *(Tier 1 Baseline)*
     * *When new changes are pushed -> Reset all approval votes*: **Checked** *(Tier 2 Dial)*
   * **Check for linked work items**: **On** (`Required` / Blocking)
   * **Check for comment resolution**: **On** (`Required` / Blocking)
   * **Limit merge types**: **On**
     * **Basic merge (no fast-forward)** and **Squash merge** are **Checked**; both Rebase options are **Unchecked**.
   * **Automatically included reviewers** (on **`example-service-api` → `main`**):
     * Reviewer: **`Example Service Maintainers`**
     * Path filter: **`/infra/*;/.azdo/*`** (`Required` / Blocking — the Azure Repos equivalent of `CODEOWNERS`).

---

### 5. Environments & Production Approval Gate (`Pipelines → Environments`)

Navigate to **Pipelines → Environments**:
* You will see **`dev`**, **`staging`**, and **`prod`**.
* Click **`prod`** → **Approvals and checks** tab:
  * You will see an active **Approvals** gate assigned to **`Example Service Maintainers`**, with *Allow approvers to approve their own runs* **Unchecked** *(Tier 1 Baseline)*.

---

### 6. Variable Groups (`Pipelines → Library`)

Navigate to **Pipelines → Library**:
* Open **`example-service-nonprod-vars`**:
  * Contains `LOG_LEVEL = Information` and `SERVICE_REGION = australiaeast`.
  * Under **Pipeline permissions**, it is restricted to explicit per-pipeline authorization rather than open to all pipelines *(Tier 1 Baseline)*.