# Cognify Ops infrastructure

Terraform for the Cognify Ops AWS account, built one small step at a time.
Each step has a note under `notes/` explaining what was built and why.

```
main.tf                    Provider, and one module call per building block
variables.tf               Account ID and CLI profile
terraform.tfvars.example   Copy to terraform.tfvars (git-ignored)
modules/
  network/                 VPC and subnets
notes/
  network/01-cidr-plan.md  The address plan
PROJECT_NOTES.md           The whole project: app, architecture, to-do
```

## Usage

```bash
cp terraform.tfvars.example terraform.tfvars   # fill in the account ID
terraform init
terraform plan
```

Terraform uses the `swop` AWS CLI profile and refuses to run against any
account other than the one in `terraform.tfvars`.
