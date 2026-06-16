# Terraform Instructions

These instructions apply to all Terraform infrastructure work. Reference this file from any project instruction set that involves Terraform.

---

## Pipeline Order

All CI/CD pipelines that include Terraform must follow this job sequence:

1. **Build** — compile/bundle the application, run lints and tests
2. **Terraform** — `init` → `plan` → `apply` (provision/update infrastructure)
3. **Deploy** — deploy the build artifact to the provisioned infrastructure

Never combine these steps into a single job. Each must be a distinct pipeline stage with explicit dependencies.

---

## Secrets Handling

- All secrets required by Terraform (e.g., `ARM_CLIENT_ID`, `ARM_TENANT_ID`, `ARM_SUBSCRIPTION_ID`) must be provided via GitHub Actions secrets or environment variables.
- **Builds must fail if secrets are not present.** Do NOT default to empty strings, placeholder values, or skip steps when secrets are missing.
- Never commit secrets to source control. Never hardcode credentials in `.tf` files or workflow definitions.

---

## Local Execution Policy

- **`terraform apply` must never be run locally.** All `init`, `plan`, and `apply` operations happen exclusively in GitHub Actions.
- The only Terraform commands permitted locally are:
  - `terraform fmt` — format files before committing
  - `terraform validate` — verify configuration syntax
  - `terraform plan` — preview changes (read-only, for local development feedback only)

---

## New Project Setup

When adding Terraform to a new project:

1. Create an `infrastructure/` directory at the project root for all `.tf` files.
2. Configure the `azurerm` backend to use the **shared Terraform state storage**:
   - **Resource Group**: `terraform-state`
   - **Storage Account**: `personaldevtfstate`
   - **Container**: `tfstate`
   - **State Key**: `<project-name>.tfstate`
3. Include a README section (or dedicated setup file) documenting the one-time setup steps:
   - Creating the blob container for the project's state key (if not already present)
   - Creating a Service Principal with OIDC federated credentials for GitHub Actions
   - Configuring the required GitHub secrets (`AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID`)
4. Use OIDC (workload identity federation) for Azure authentication — no client secrets.

### Backend Block Template

```hcl
terraform {
  backend "azurerm" {
    resource_group_name  = "terraform-state"
    storage_account_name = "personaldevtfstate"
    container_name       = "tfstate"
    key                  = "<project-name>.tfstate"
  }
}
```

---

## Formatting Requirement

- Run `terraform fmt` on all modified `.tf` files before marking any task as complete.
- CI pipelines must include a `terraform fmt -check` step in the build job to enforce formatting.
- If `terraform fmt -check` fails, fix the formatting locally and re-commit before proceeding.
