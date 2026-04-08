# Terraform PoC - PrivateLink with Overlapping CIDRs

This lab demonstrates a simple proof of concept for exposing a private workload **without a public NLB**, even when the **partner VPC uses the same CIDR** as the workload VPC.

## What this lab creates

- `vpc-workload` with CIDR `10.10.0.0/16`
- `vpc-partner` with CIDR `10.10.0.0/16` (intentionally overlapping)
- One EC2 instance in the workload VPC running a simple HTTP server
- One **internal** Network Load Balancer in front of the workload instance
- One VPC Endpoint Service (PrivateLink provider side)
- One Interface VPC Endpoint in the partner VPC (PrivateLink consumer side)
- One EC2 instance in the partner VPC for testing with `curl`

## What this proves

1. You can keep the service private.
2. You do not need a public IP on the NLB.
3. Overlapping CIDRs do not prevent service consumption through PrivateLink.
4. This is a cleaner option than using a public NLB just to avoid IP conflict with partners.

## Important note

This lab does **not** try to route traffic directly between the two VPCs. That is intentional.
The point is to show that **PrivateLink exposes the service privately without relying on broad routed connectivity**.

## Prerequisites

- Terraform >= 1.5
- AWS credentials configured
- One AWS region enabled in your account
- Permission to create VPC, EC2, NLB, VPC Endpoints, IAM roles, and SSM parameter reads

## Usage

```bash
terraform init
terraform plan
terraform apply
```

After apply, connect to the partner instance using SSM Session Manager if supported in your environment, or temporarily add a management method of your choice.
Then test:

```bash
curl http://<private_dns_name_from_output>
```

The output should come from the workload instance through the internal NLB and PrivateLink.

## Destroy

```bash
terraform destroy
```

## Suggested demo script

1. Show both VPC CIDRs are identical.
2. Show the NLB is **internal**, not internet-facing.
3. Show the Endpoint Service and Interface Endpoint were created.
4. From the partner instance, `curl` the endpoint DNS.
5. Show the response comes from the workload service.

## Security classification

- **A: Segurança Básica**: Keep the NLB internal.
- **B: Segurança Recomendada**: Use PrivateLink to publish the service privately.
- **C: Segurança Opcional**: Extend later with TGW, inspection VPC, and firewall simulation.
