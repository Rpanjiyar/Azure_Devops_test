# Azure DevOps Mini Task - Production-ready version (Python 3.9)

This repository contains:
- A minimal Python Flask app (app/)
- pytest unit test
- Terraform IaC to provision:
  - Resource Group
  - App Service Plan (Linux)
  - Production App Service (Python 3.9)
  - Staging slot
  - Application Insights
  - User Assigned Managed Identity
  - Key Vault + secret
- Azure DevOps pipeline (pipeline.yml) with stages:
  Build -> Test -> Deploy Staging -> Manual Approval -> Deploy Prod (swap slots)

## How to run / deploy

### 1) Provision infrastructure (Terraform)
Prerequisites:
- Azure CLI installed and logged in (`az login`)
- Terraform installed
- Your Azure subscription set (`az account set --subscription <ID|NAME>`)

Commands:
```bash
cd infra
terraform init
terraform apply -auto-approve
```
> In this repo the Terraform file is at the repository root as `main.tf`. You can run `terraform init` and `terraform apply` from the repo root.

### 2) Configure Azure DevOps pipeline
- Create an Azure DevOps project and a Service Connection to your Azure subscription (Service Principal).
- Update `pipeline.yml`:
  - Replace `<YOUR-SERVICE-CONNECTION>` with your service connection name.
  - Replace `<APP_NAME>` and `<RESOURCE_GROUP>` placeholders with values you used in Terraform (defaults in `main.tf`).
  - Set approver email `<approver-azure-devops-email>`.

- Commit pipeline.yml to `main` branch and create a pipeline in Azure DevOps pointing to this repo.

### 3) How the Blue/Green deployment works
- Deploys the app package to the **staging** slot.
- After manual verification and approval, the pipeline runs an `az webapp deployment slot swap` to swap staging with production (zero-downtime swap).

## Assumptions made
- Using Terraform-only IaC targeting Azure.
- Python 3.9 runtime on Linux App Service.
- Key Vault secret is created by Terraform; in prod workflows you'd create secrets via CI/CD secure variables or Key Vault separately.
- Basic SKU (B1) for cost control. For production, choose Standard or Premium SKUs.

## Production improvements included
- pytest tests (unit test example).
- Application Insights integrated for monitoring.
- User-assigned managed identity + Key Vault secret access so App Service can read secrets securely.
- Staging slot + slot swap (blue/green).
- Pipeline with manual approval gate before production swap.
- Structured logging in app.

## Further production improvements (optional)
- Add infrastructure state locking (e.g., remote backend for terraform state: Azure Storage).
- Add more robust test suite, integration tests, and security scanning (Snyk, bandit).
- Implement canary releases with traffic routing (Azure Front Door or App Service slot traffic routing).
- Secure service principal credentials in Azure DevOps variable groups linked to Key Vault.
- Autoscale rules, health checks, and alerting rules in Application Insights/Monitor.
- CI: containerize app and host in ACR + AKS for microservices-style workloads.

