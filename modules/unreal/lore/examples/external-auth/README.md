# External Auth Example

Default topology (write tier + 2 edge pods) with an external IdP (Okta, Azure AD, etc.).

## What it adds over default

- JWT validation against your IdP's JWKS endpoint
- Requires `auth_jwk_endpoint`, `auth_jwt_issuer`, `auth_jwt_audience` variables

## Usage

```bash
cp terraform.tfvars.example terraform.tfvars
# Edit with your container image, CIDR, and IdP details

terraform init
terraform apply
```

## Connect

Obtain a token from your IdP, then clone:

```bash
lore clone --token "$TOKEN" lores://<edge_1_ip>:41337/my-repo
```

## Tear down

```bash
terraform destroy
# Takes ~6 minutes
```
