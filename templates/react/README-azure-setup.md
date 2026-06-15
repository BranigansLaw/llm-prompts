## Azure Setup (One-Time)

The app deploys to **Azure Static Web Apps** via Terraform run in GitHub Actions. Terraform state is stored in Azure Blob Storage. The state backend (`terraform-state` resource group / `personaldevtfstate` storage account) already exists.

### 1. Create the Terraform state container

```powershell
az login

# Create the blob container for this project's state
az storage container create `
  --name tfstate `
  --account-name personaldevtfstate
```

### 2. Create a Service Principal with OIDC (federated credentials)

Run this PowerShell script (replace `{{APP_NAME}}` and `<GITHUB_ORG>/<GITHUB_REPO>`):

```powershell
$SUBSCRIPTION_ID = (az account show --query id -o tsv)
$APP_ID = (az ad app create --display-name "{{APP_NAME}}-github-actions" --query appId -o tsv)

az ad sp create --id $APP_ID

az role assignment create `
  --assignee $APP_ID `
  --role Contributor `
  --scope /subscriptions/$SUBSCRIPTION_ID

# Add federated credential for GitHub Actions (main branch)
@{
  name      = "github-main"
  issuer    = "https://token.actions.githubusercontent.com"
  subject   = "repo:<GITHUB_ORG>/<GITHUB_REPO>:ref:refs/heads/main"
  audiences = @("api://AzureADTokenExchange")
} | ConvertTo-Json | Set-Content fedcred.json

az ad app federated-credential create --id $APP_ID --parameters fedcred.json
Remove-Item fedcred.json

Write-Host "`nValues for GitHub Secrets:"
Write-Host "AZURE_CLIENT_ID: $APP_ID"
Write-Host "AZURE_TENANT_ID: $((az account show --query tenantId -o tsv))"
Write-Host "AZURE_SUBSCRIPTION_ID: $SUBSCRIPTION_ID"
```

### 3. Configure GitHub Secrets

Add the following secrets to the GitHub repository:

| Secret | Value |
|--------|-------|
| `AZURE_CLIENT_ID` | The Application (client) ID from the app registration |
| `AZURE_TENANT_ID` | Your Azure AD tenant ID |
| `AZURE_SUBSCRIPTION_ID` | Your Azure subscription ID |

To retrieve these values later:

```powershell
az account show --query "{TenantId:tenantId, SubscriptionId:id}" -o table
az ad app list --display-name "{{APP_NAME}}-github-actions" --query "[0].appId" -o tsv
```

No client secret is needed — the pipeline uses OIDC (workload identity federation).

## CI/CD Pipeline

The single workflow at `.github/workflows/deploy.yml` runs on push to `main`:

1. **Build** — install, lint, type-check, `terraform fmt -check`, test, build
2. **Terraform** — init, plan, apply (provisions/updates the Azure Static Web App)
3. **Deploy** — uploads the `dist/` artifact to the Static Web App

Terraform is **never run locally** (other than `terraform fmt` or `terraform validate` for local verification). All infrastructure changes flow through the pipeline.

## Infrastructure

Terraform files live in `infrastructure/`. The backend is configured to use:

- **Resource Group**: `terraform-state`
- **Storage Account**: `personaldevtfstate`
- **Container**: `tfstate`
- **State Key**: `{{APP_NAME}}.tfstate`
