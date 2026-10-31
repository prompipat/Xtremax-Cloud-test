# network

Creates the two-AZ VPC, six subnets, NAT/internet routing and tier NACLs.

Inherits the root AWS provider and project tags. This module's mocked tests do not create AWS resources.

## Inputs

| Name | Description |
|---|---|
| `name` | Name prefix for network resources. |
| `vpc_cidr` | IPv4 /16 network, divided into six /24 subnets. |
| `availability_zones` | Two distinct standard availability zones in the provider region. |
| `single_nat_gateway` | Use one NAT gateway for a lab; false gives each AZ its own gateway. |

## Outputs

| Name | Description |
|---|---|
| `vpc_id` | VPC identifier used by workload security groups. |
| `subnets` | Subnet IDs, CIDRs and zones grouped by workload tier. |
| `nat_gateway_ids` | NAT gateway IDs keyed by their availability zone. |

See `variables.tf` for exact types, defaults and validation. The complete architecture, dependencies and limitations are in the root `docs/report.md` and `docs/report.pdf`.
