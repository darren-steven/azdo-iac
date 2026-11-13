# Gemini / Antigravity Workspace Rules

@[AGENTS.md](./AGENTS.md)

## Gemini & Antigravity Specific Notes

- **Skills Discovery**: Activate the appropriate skill from `.agents/skills/<skill-name>/SKILL.md` whenever the user's request matches one of the workflows listed in `AGENTS.md` (adjusting a dial, onboarding a project, creating a new baseline dial, authoring an AzDO module, or troubleshooting a policy failure).
- **Hierarchical Rules**: Pay close attention to directory-scoped `AGENTS.md` files in `config/AGENTS.md` and `modules/AGENTS.md` when reading or editing files in those directories.
- **Sandbox Execution**: Always run `./scripts/validate.sh` inside the standard sandbox (`BypassSandbox: false`) after editing YAML configs, schemas, policies, or OpenTofu files.
