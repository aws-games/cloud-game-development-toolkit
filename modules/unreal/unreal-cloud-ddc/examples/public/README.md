# Public Access Examples

**Internet-accessible DDC with public EKS API endpoint**

## Access Pattern
- **Infrastructure**: NLB (internet-facing), EKS (public API endpoint)
- **Application**: DDC pods accessible via public NLB
- **Service**: ScyllaDB (private, VPC-only)

## Security
- EKS API restricted to specific CIDR blocks
- HTTPS with ACM certificates required
- Security groups control access
- Database remains private within VPC

## Use Cases
- External developers and remote teams
- CI/CD systems requiring direct access
- Multi-cloud or hybrid environments

## Examples
- **single-region/**: Basic single-region deployment
- **multi-region/**: Multi-region with cross-region replication