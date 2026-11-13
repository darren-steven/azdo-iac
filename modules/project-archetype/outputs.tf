output "project_id" {
  description = "Azure DevOps Project GUID."
  value       = azuredevops_project.this.id
}

output "repository_ids" {
  description = "Map of repository names to their GUIDs."
  value       = local.all_managed_repo_ids
}

output "team_descriptors" {
  description = "Map of team names to their AzDO security descriptors."
  value       = { for k, t in azuredevops_team.teams : k => t.descriptor }
}
