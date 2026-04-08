# PrivateLink overlap PoC with Session Manager only

This Terraform lab creates a low-complexity PoC to prove that a service can be consumed privately even when the **provider VPC** and the **partner VPC** intentionally use the **same CIDR range**.

## What this lab builds

- 1 workload VPC with CIDR `10.10.0.0/16`
- 1 partner VPC with CIDR `10.10.0.0/16` (overlapping on purpose)
- 1 Amazon Linux 2023 EC2 in the workload VPC, without public IP
- 1 internal Network Load Balancer in front of the workload EC2
- 1 PrivateLink Endpoint Service backed by the internal NLB
- 1 Amazon Linux 2023 EC2 in the partner VPC, without public IP
- 1 Interface VPC Endpoint in the partner VPC to consume the service privately
- 3 SSM interface endpoints in **each VPC**: `ssm`, `ssmmessages`, `ec2messages`
- IAM role/profile so both EC2 instances are managed only through Session Manager

## Security categories

- **A: Segurança Básica**
  - No public IPs on EC2 instances
  - Session Manager instead of SSH
  - Internal NLB instead of public NLB

- **B: Segurança Recomendada**
  - PrivateLink to publish the service privately to a partner
  - Interface VPC Endpoints for SSM instead of NAT Gateway

- **C: Segurança Opcional**
  - In a next version, add TGW and an inspection VPC/firewall

## Usage

```bash
terraform init
terraform plan
terraform apply
```

When the apply finishes, use the outputs to open Session Manager sessions.

Example:

```bash
aws ssm start-session --target i-xxxxxxxxxxxxxxxxx --region us-east-1
```

From the **partner** instance, test the private service using the DNS name from `partner_vpce_dns_names`:

```bash
curl http://<dns-name-from-output>
```

Expected result: a JSON response similar to:

```json
{"message": "PrivateLink PoC OK", "hostname": "...", "path": "/", "source": "..."}
```

## Notes

- This lab intentionally avoids NAT Gateway to keep the traffic private and the design simpler.
- It also avoids TGW/VPN in version 1 so the PoC remains focused on the main point: **private access without public IPs, even with overlapping CIDRs**.
- Make sure your local workstation already has:
  - AWS CLI configured
  - Session Manager Plugin installed

## Destroy

```bash
terraform destroy
```
