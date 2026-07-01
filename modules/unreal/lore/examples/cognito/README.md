# Cognito Auth Example

Default topology (write tier + 2 edge pods) with Cognito authentication and X-Ray observability.

## What it adds over default

- Cognito User Pool with app client (client_credentials grant)
- ADOT sidecar for X-Ray tracing
- Deletion protection on DynamoDB tables

## Usage

```bash
cp terraform.tfvars.example terraform.tfvars
# Edit with your container image and CIDR

terraform init
terraform apply
```

## Connect

Obtain a token, then clone:

```bash
TOKEN=$(curl -s -X POST "<cognito_token_endpoint>" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=client_credentials&client_id=<client_id>&client_secret=<client_secret>" \
  | jq -r '.access_token')

lore clone --token "$TOKEN" lores://<edge_1_ip>:41337/my-repo
```

## Tear down

```bash
terraform destroy
# Takes ~6 minutes
```
