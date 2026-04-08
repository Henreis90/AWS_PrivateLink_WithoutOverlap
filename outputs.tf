output "workload_vpc_id" {
  description = "ID of the workload VPC"
  value       = aws_vpc.workload.id
}

output "partner_vpc_id" {
  description = "ID of the partner VPC"
  value       = aws_vpc.partner.id
}

output "workload_vpc_cidr" {
  description = "CIDR of the workload VPC"
  value       = aws_vpc.workload.cidr_block
}

output "partner_vpc_cidr" {
  description = "CIDR of the partner VPC"
  value       = aws_vpc.partner.cidr_block
}

output "endpoint_service_name" {
  description = "PrivateLink endpoint service name"
  value       = aws_vpc_endpoint_service.workload.service_name
}

output "vpce_dns_names" {
  description = "DNS names for the interface endpoint. Use one of these from the partner instance with curl."
  value       = aws_vpc_endpoint.partner_to_workload.dns_entry
}

output "internal_nlb_dns_name" {
  description = "DNS name of the internal NLB"
  value       = aws_lb.workload_internal_nlb.dns_name
}

output "partner_instance_public_ip" {
  description = "Public IP of the partner test instance"
  value       = aws_instance.partner.public_ip
}

output "workload_instance_public_ip" {
  description = "Public IP of the workload instance"
  value       = aws_instance.workload.public_ip
}

output "poc_summary" {
  description = "Quick summary for demonstration"
  value = {
    overlapping_cidrs = aws_vpc.workload.cidr_block == aws_vpc.partner.cidr_block
    nlb_is_internal   = aws_lb.workload_internal_nlb.internal
    service_is_public = false
  }
}
