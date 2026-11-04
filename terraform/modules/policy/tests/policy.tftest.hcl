# Runs without Azure credentials: the provider is mocked.
mock_provider "azurerm" {
  mock_data "azurerm_policy_definition" {
    defaults = {
      id = "/providers/Microsoft.Authorization/policyDefinitions/e56962a6-4747-49cd-b67b-bf8b01975c4c"
    }
  }

  mock_resource "azurerm_subscription_policy_assignment" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/providers/Microsoft.Authorization/policyAssignments/mock"
    }
  }
}

variables {
  subscription_id = "/subscriptions/00000000-0000-0000-0000-000000000000"
  location        = "uksouth"
}

run "uk_only" {
  command = apply

  assert {
    condition     = jsondecode(azurerm_subscription_policy_assignment.allowed_locations.parameters).listOfAllowedLocations.value == ["uksouth", "ukwest"]
    error_message = "Resources must be limited to the UK regions."
  }
}

run "one_require_and_inherit_assignment_per_tag" {
  command = apply

  variables {
    required_tags = ["cost-center", "owner"]
  }

  assert {
    condition     = toset(keys(azurerm_subscription_policy_assignment.inherit_rg_tag)) == toset(["cost-center", "owner"])
    error_message = "Each required tag needs an inherit assignment."
  }

  assert {
    condition     = alltrue([for r in azurerm_role_assignment.inherit_rg_tag : r.role_definition_name == "Tag Contributor"])
    error_message = "Modify policies need Tag Contributor and nothing broader."
  }
}

run "audit_only_rollout" {
  command = apply

  variables {
    enforce = false
  }

  assert {
    condition     = !azurerm_subscription_policy_assignment.allowed_locations.enforce
    error_message = "enforce = false must put assignments in DoNotEnforce mode."
  }
}

run "rejects_bare_subscription_guid" {
  command = plan

  variables {
    subscription_id = "00000000-0000-0000-0000-000000000000"
  }

  expect_failures = [var.subscription_id]
}
