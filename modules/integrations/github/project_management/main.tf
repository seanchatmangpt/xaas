terraform {
  required_providers {
    github = {
      source  = "integrations/github"
      version = "5.41.0"
    }
  }
}

locals {
  repository_name = "xaas"
  github_owner    = "seanchatmangpt"
}

resource "github_repository" "kanban" {
  name                   = local.repository_name
  description            = "Real xaas Ash-ecosystem platform, built on the BEAMOps deployment foundation. Renamed from engineering_elixir_applications this session."
  visibility             = "public"
  has_issues             = true
  has_projects           = true
  has_wiki               = true
  auto_init              = false
  homepage_url           = "https://pragprog.com/titles/beamops/engineering-elixir-applications/"
  gitignore_template     = "Terraform"
  delete_branch_on_merge = true
}

resource "github_repository_milestone" "epics" {
  for_each    = var.milestones
  owner       = local.github_owner
  repository  = local.repository_name
  title       = each.value.title
  description = replace(each.value.description, "\n", " ")
  due_date    = each.value.due_date
  depends_on  = [github_repository.kanban]
}

resource "github_issue_label" "issues_labels" {
  for_each   = var.labels
  repository = local.repository_name
  name       = each.value.name
  color      = each.value.color
  depends_on = [github_repository.kanban]
}

resource "github_issue" "tasks" {
  count      = length(var.issues)
  repository = github_repository.kanban.name
  title      = var.issues[count.index].title
  body       = var.issues[count.index].body
  milestone_number = github_repository_milestone.epics[
    var.issues[count.index].milestone
  ].number
  labels = [for l in var.issues[count.index].labels :
    github_issue_label.issues_labels[l].name
  ]
}

provider "github" {
  owner = local.github_owner
}

