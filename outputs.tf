output "region" {
  value = var.region
}

output "workload_instance_id" {
  value = aws_instance.workload.id
}

output "partner_instance_id" {
  value = aws_instance.partner.id
}

output "workload_instance_session_manager_command" {
  value = "aws ssm start-session --target ${aws_instance.workload.id} --region ${var.region}"
}

output "partner_instance_session_manager_command" {
  value = "aws ssm start-session --target ${aws_instance.partner.id} --region ${var.region}"
}

output "internal_nlb_dns_name" {
  value = aws_lb.internal_nlb.dns_name
}

output "endpoint_service_name" {
  value = aws_vpc_endpoint_service.workload.service_name
}

output "partner_vpce_dns_names" {
  value = aws_vpc_endpoint.partner_to_service.dns_entry[*].dns_name
}

output "test_from_partner" {
  value = "After opening a Session Manager shell on the partner instance, run: curl http://${aws_vpc_endpoint.partner_to_service.dns_entry[0].dns_name}"
}
