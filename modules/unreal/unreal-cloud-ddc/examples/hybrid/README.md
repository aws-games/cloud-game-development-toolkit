# Hybrid Access Examples

**Flexible DDC with both public and private EKS API endpoints**

## Access Pattern
- **Infrastructure**: NLB (internet-facing), EKS (public + private API + NLB proxy)
- **Application**: DDC pods accessible via public NLB and VPC-internal access
- **Service**: ScyllaDB (private, VPC-only)

## Security
- Public endpoint restricted to specific CIDRs
- Private endpoint for VPC-internal access
- NLB proxy provides additional private access option
- Flexible security boundaries

## Use Cases
- Mixed environments (internal + external teams)
- Gradual migration from public to private
- Development (public) + production (private) workflows
- Maximum flexibility and future-proofing

## Examples
- **single-region/**: Comprehensive single-region deployment with all features
- **multi-region/**: Full multi-region deployment with hybrid access