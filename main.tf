provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project   = var.project_name
      ManagedBy = "Terraform"
      Purpose   = "PrivateLink-Overlap-PoC"
    }
  }
}

locals {
  workload_subnet_a = cidrsubnet(var.workload_vpc_cidr, 8, 1)
  workload_subnet_b = cidrsubnet(var.workload_vpc_cidr, 8, 2)
  partner_subnet_a  = cidrsubnet(var.partner_vpc_cidr, 8, 1)
  partner_subnet_b  = cidrsubnet(var.partner_vpc_cidr, 8, 2)

  endpoints = toset([
    "ssm",
    "ssmmessages",
    "ec2messages",
  ])
}

data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_ssm_parameter" "al2023_ami" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

resource "aws_vpc" "workload" {
  cidr_block           = var.workload_vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${var.project_name}-workload-vpc"
  }
}

resource "aws_vpc" "partner" {
  cidr_block           = var.partner_vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${var.project_name}-partner-vpc"
  }
}

resource "aws_subnet" "workload_a" {
  vpc_id                  = aws_vpc.workload.id
  cidr_block              = local.workload_subnet_a
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = false

  tags = {
    Name = "${var.project_name}-workload-a"
  }
}

resource "aws_subnet" "workload_b" {
  vpc_id                  = aws_vpc.workload.id
  cidr_block              = local.workload_subnet_b
  availability_zone       = data.aws_availability_zones.available.names[1]
  map_public_ip_on_launch = false

  tags = {
    Name = "${var.project_name}-workload-b"
  }
}

resource "aws_subnet" "partner_a" {
  vpc_id                  = aws_vpc.partner.id
  cidr_block              = local.partner_subnet_a
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = false

  tags = {
    Name = "${var.project_name}-partner-a"
  }
}

resource "aws_subnet" "partner_b" {
  vpc_id                  = aws_vpc.partner.id
  cidr_block              = local.partner_subnet_b
  availability_zone       = data.aws_availability_zones.available.names[1]
  map_public_ip_on_launch = false

  tags = {
    Name = "${var.project_name}-partner-b"
  }
}

resource "aws_route_table" "workload" {
  vpc_id = aws_vpc.workload.id

  tags = {
    Name = "${var.project_name}-workload-rt"
  }
}

resource "aws_route_table" "partner" {
  vpc_id = aws_vpc.partner.id

  tags = {
    Name = "${var.project_name}-partner-rt"
  }
}

resource "aws_route_table_association" "workload_a" {
  subnet_id      = aws_subnet.workload_a.id
  route_table_id = aws_route_table.workload.id
}

resource "aws_route_table_association" "workload_b" {
  subnet_id      = aws_subnet.workload_b.id
  route_table_id = aws_route_table.workload.id
}

resource "aws_route_table_association" "partner_a" {
  subnet_id      = aws_subnet.partner_a.id
  route_table_id = aws_route_table.partner.id
}

resource "aws_route_table_association" "partner_b" {
  subnet_id      = aws_subnet.partner_b.id
  route_table_id = aws_route_table.partner.id
}

resource "aws_security_group" "endpoint_workload" {
  name        = "${var.project_name}-endpoint-workload-sg"
  description = "Allows VPC interface endpoints in workload VPC to receive HTTPS from local workloads"
  vpc_id      = aws_vpc.workload.id

  ingress {
    description = "HTTPS from workload VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.workload_vpc_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-endpoint-workload-sg"
  }
}

resource "aws_security_group" "endpoint_partner" {
  name        = "${var.project_name}-endpoint-partner-sg"
  description = "Allows VPC interface endpoints in partner VPC to receive HTTPS from local workloads"
  vpc_id      = aws_vpc.partner.id

  ingress {
    description = "HTTPS from partner VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.partner_vpc_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-endpoint-partner-sg"
  }
}

resource "aws_vpc_endpoint" "workload_ssm" {
  for_each            = local.endpoints
  vpc_id              = aws_vpc.workload.id
  service_name        = "com.amazonaws.${var.region}.${each.value}"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true
  subnet_ids          = [aws_subnet.workload_a.id, aws_subnet.workload_b.id]
  security_group_ids  = [aws_security_group.endpoint_workload.id]

  tags = {
    Name = "${var.project_name}-workload-${each.value}"
  }
}

resource "aws_vpc_endpoint" "partner_ssm" {
  for_each            = local.endpoints
  vpc_id              = aws_vpc.partner.id
  service_name        = "com.amazonaws.${var.region}.${each.value}"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true
  subnet_ids          = [aws_subnet.partner_a.id, aws_subnet.partner_b.id]
  security_group_ids  = [aws_security_group.endpoint_partner.id]

  tags = {
    Name = "${var.project_name}-partner-${each.value}"
  }
}

resource "aws_iam_role" "ec2_ssm" {
  name = "${var.project_name}-ec2-ssm-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.ec2_ssm.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ec2_ssm" {
  name = "${var.project_name}-ec2-ssm-profile"
  role = aws_iam_role.ec2_ssm.name
}

resource "aws_security_group" "workload_instance" {
  name        = "${var.project_name}-workload-instance-sg"
  description = "Allows HTTP only from internal NLB and local diagnostics"
  vpc_id      = aws_vpc.workload.id

  ingress {
    description = "HTTP from inside workload VPC"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [var.workload_vpc_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-workload-instance-sg"
  }
}

resource "aws_security_group" "partner_instance" {
  name        = "${var.project_name}-partner-instance-sg"
  description = "Allows egress from partner test host"
  vpc_id      = aws_vpc.partner.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-partner-instance-sg"
  }
}

resource "aws_instance" "workload" {
  ami                    = data.aws_ssm_parameter.al2023_ami.value
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.workload_a.id
  vpc_security_group_ids = [aws_security_group.workload_instance.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2_ssm.name
  associate_public_ip_address = false

  user_data = <<-EOF
              #!/bin/bash
              set -euxo pipefail
              cat > /usr/local/bin/privatelink-poc-server.py <<'PYEOF'
              import http.server
              import socketserver
              import json
              import os
              class Handler(http.server.BaseHTTPRequestHandler):
                  def do_GET(self):
                      payload = {
                          "message": "PrivateLink PoC OK",
                          "hostname": os.uname().nodename,
                          "path": self.path,
                          "source": self.client_address[0]
                      }
                      body = json.dumps(payload).encode()
                      self.send_response(200)
                      self.send_header("Content-Type", "application/json")
                      self.send_header("Content-Length", str(len(body)))
                      self.end_headers()
                      self.wfile.write(body)
              with socketserver.TCPServer(("0.0.0.0", 80), Handler) as httpd:
                  httpd.serve_forever()
              PYEOF
              cat > /etc/systemd/system/privatelink-poc.service <<'SERVICE'
              [Unit]
              Description=PrivateLink PoC HTTP service
              After=network.target

              [Service]
              ExecStart=/usr/bin/python3 /usr/local/bin/privatelink-poc-server.py
              Restart=always
              RestartSec=3

              [Install]
              WantedBy=multi-user.target
              SERVICE
              systemctl daemon-reload
              systemctl enable privatelink-poc.service
              systemctl start privatelink-poc.service
              EOF

  tags = {
    Name = "${var.project_name}-workload"
  }
}

resource "aws_instance" "partner" {
  ami                    = data.aws_ssm_parameter.al2023_ami.value
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.partner_a.id
  vpc_security_group_ids = [aws_security_group.partner_instance.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2_ssm.name
  associate_public_ip_address = false

  user_data = <<-EOF
              #!/bin/bash
              set -euxo pipefail
              cat > /etc/motd <<'MOTD'
              PrivateLink partner test instance.
              Use Session Manager and test the service with curl against the VPC endpoint DNS name.
              MOTD
              EOF

  tags = {
    Name = "${var.project_name}-partner"
  }
}

resource "aws_lb" "internal_nlb" {
  name               = substr(replace("${var.project_name}-nlb", "/[^a-zA-Z0-9-]/", ""), 0, 32)
  internal           = true
  load_balancer_type = "network"
  subnets            = [aws_subnet.workload_a.id, aws_subnet.workload_b.id]

  enable_deletion_protection = false

  tags = {
    Name = "${var.project_name}-internal-nlb"
  }
}

resource "aws_lb_target_group" "workload" {
  name        = substr(replace("${var.project_name}-tg", "/[^a-zA-Z0-9-]/", ""), 0, 32)
  port        = 80
  protocol    = "TCP"
  target_type = "instance"
  vpc_id      = aws_vpc.workload.id

  health_check {
    enabled             = true
    protocol            = "HTTP"
    path                = "/"
    port                = "80"
    interval            = 30
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 6
    matcher             = "200"
  }

  tags = {
    Name = "${var.project_name}-tg"
  }
}

resource "aws_lb_target_group_attachment" "workload" {
  target_group_arn = aws_lb_target_group.workload.arn
  target_id        = aws_instance.workload.id
  port             = 80
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.internal_nlb.arn
  port              = 80
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.workload.arn
  }
}

resource "aws_vpc_endpoint_service" "workload" {
  acceptance_required        = false
  network_load_balancer_arns = [aws_lb.internal_nlb.arn]

  tags = {
    Name = "${var.project_name}-endpoint-service"
  }
}

resource "aws_security_group" "privatelink_consumer" {
  name        = "${var.project_name}-privatelink-consumer-sg"
  description = "Allows partner host to connect to the Interface Endpoint over HTTP"
  vpc_id      = aws_vpc.partner.id

  ingress {
    description = "HTTP from partner VPC"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [var.partner_vpc_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-privatelink-consumer-sg"
  }
}

resource "aws_vpc_endpoint" "partner_to_service" {
  vpc_id              = aws_vpc.partner.id
  service_name        = aws_vpc_endpoint_service.workload.service_name
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = false
  subnet_ids          = [aws_subnet.partner_a.id, aws_subnet.partner_b.id]
  security_group_ids  = [aws_security_group.privatelink_consumer.id]

  tags = {
    Name = "${var.project_name}-partner-to-service"
  }
}
