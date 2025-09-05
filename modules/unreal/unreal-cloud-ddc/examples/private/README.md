# Private Access Examples

**VPC-only DDC with private EKS API endpoint**

## Access Pattern
- **Infrastructure**: NLB (internal), EKS (private API + NLB proxy)
- **Application**: DDC pods accessible only within VPC
- **Service**: ScyllaDB (private, VPC-only)

## Security
- EKS API only accessible from VPC
- NLB proxy provides controlled external access to EKS
- All traffic stays within VPC boundaries
- Maximum security isolation

## Use Cases
- High security environments
- Compliance requirements (SOC2, HIPAA)
- Internal-only development teams
- Air-gapped or restricted networks

## Examples
- **single-region/**: Basic single-region private deployment
- **multi-region/**: Multi-region private with cross-region replication