data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  azs = slice(data.aws_availability_zones.available.names, 0, 2)

  workload_public_subnets = {
    az1 = {
      cidr = "10.10.1.0/24"
      az   = local.azs[0]
    }
    az2 = {
      cidr = "10.10.2.0/24"
      az   = local.azs[1]
    }
  }

  partner_public_subnets = {
    az1 = {
      cidr = "10.10.11.0/24"
      az   = local.azs[0]
    }
    az2 = {
      cidr = "10.10.12.0/24"
      az   = local.azs[1]
    }
  }
}

# -----------------------------
# AMI lookup
# -----------------------------
data "aws_ssm_parameter" "al2023_ami" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

# -----------------------------
# Workload VPC
# -----------------------------
resource "aws_vpc" "workload" {
  cidr_block           = var.workload_vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${var.project_name}-workload-vpc"
  }
}

resource "aws_internet_gateway" "workload" {
  vpc_id = aws_vpc.workload.id

  tags = {
    Name = "${var.project_name}-workload-igw"
  }
}

resource "aws_subnet" "workload" {
  for_each = local.workload_public_subnets

  vpc_id                  = aws_vpc.workload.id
  cidr_block              = each.value.cidr
  availability_zone       = each.value.az
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.project_name}-workload-${each.key}"
  }
}

resource "aws_route_table" "workload_public" {
  vpc_id = aws_vpc.workload.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.workload.id
  }

  tags = {
    Name = "${var.project_name}-workload-public-rt"
  }
}

resource "aws_route_table_association" "workload_public" {
  for_each = aws_subnet.workload

  subnet_id      = each.value.id
  route_table_id = aws_route_table.workload_public.id
}

resource "aws_security_group" "workload_instance" {
  name        = "${var.project_name}-workload-sg"
  description = "Allow HTTP from NLB subnets and admin access if needed"
  vpc_id      = aws_vpc.workload.id

  ingress {
    description = "HTTP from workload VPC"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [var.workload_vpc_cidr]
  }

  ingress {
    description = "ICMP for optional troubleshooting"
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = [var.workload_vpc_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-workload-sg"
  }
}

resource "aws_instance" "workload" {
  ami                         = data.aws_ssm_parameter.al2023_ami.value
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.workload["az1"].id
  vpc_security_group_ids      = [aws_security_group.workload_instance.id]
  associate_public_ip_address = true

  user_data = <<-EOFUSERDATA
              #!/bin/bash
              dnf update -y
              dnf install -y python3
              mkdir -p /opt/app
              cat > /opt/app/index.html <<'EOT'
              <html>
              <head><title>PrivateLink PoC</title></head>
              <body>
              <h1>PrivateLink PoC funcionando</h1>
              <p>Serviço privado atrás de NLB interno.</p>
              <p>Hostname: $(hostname)</p>
              </body>
              </html>
              EOT
              cd /opt/app
              nohup python3 -m http.server 80 >/var/log/http.server.log 2>&1 &
              EOFUSERDATA

  tags = {
    Name = "${var.project_name}-workload-instance"
  }
}

resource "aws_lb" "workload_internal_nlb" {
  name               = substr(replace("${var.project_name}-nlb", "/[^a-zA-Z0-9-]/", ""), 0, 32)
  internal           = true
  load_balancer_type = "network"
  subnets            = [for s in aws_subnet.workload : s.id]

  enable_cross_zone_load_balancing = true

  tags = {
    Name = "${var.project_name}-internal-nlb"
  }
}

resource "aws_lb_target_group" "workload_http" {
  name        = substr(replace("${var.project_name}-tg", "/[^a-zA-Z0-9-]/", ""), 0, 32)
  port        = 80
  protocol    = "TCP"
  target_type = "instance"
  vpc_id      = aws_vpc.workload.id

  health_check {
    enabled             = true
    interval            = 30
    port                = "80"
    protocol            = "TCP"
    healthy_threshold   = 3
    unhealthy_threshold = 3
  }

  tags = {
    Name = "${var.project_name}-tg-http"
  }
}

resource "aws_lb_target_group_attachment" "workload_http" {
  target_group_arn = aws_lb_target_group.workload_http.arn
  target_id        = aws_instance.workload.id
  port             = 80
}

resource "aws_lb_listener" "workload_http" {
  load_balancer_arn = aws_lb.workload_internal_nlb.arn
  port              = 80
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.workload_http.arn
  }
}

resource "aws_vpc_endpoint_service" "workload" {
  acceptance_required        = false
  network_load_balancer_arns = [aws_lb.workload_internal_nlb.arn]

  tags = {
    Name = "${var.project_name}-endpoint-service"
  }
}

# -----------------------------
# Partner VPC
# -----------------------------
resource "aws_vpc" "partner" {
  cidr_block           = var.partner_vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${var.project_name}-partner-vpc"
  }
}

resource "aws_internet_gateway" "partner" {
  vpc_id = aws_vpc.partner.id

  tags = {
    Name = "${var.project_name}-partner-igw"
  }
}

resource "aws_subnet" "partner" {
  for_each = local.partner_public_subnets

  vpc_id                  = aws_vpc.partner.id
  cidr_block              = each.value.cidr
  availability_zone       = each.value.az
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.project_name}-partner-${each.key}"
  }
}

resource "aws_route_table" "partner_public" {
  vpc_id = aws_vpc.partner.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.partner.id
  }

  tags = {
    Name = "${var.project_name}-partner-public-rt"
  }
}

resource "aws_route_table_association" "partner_public" {
  for_each = aws_subnet.partner

  subnet_id      = each.value.id
  route_table_id = aws_route_table.partner_public.id
}

resource "aws_security_group" "partner_instance" {
  name        = "${var.project_name}-partner-instance-sg"
  description = "Security group for partner test instance"
  vpc_id      = aws_vpc.partner.id

  ingress {
    description = "Optional SSH from your IP if you add a key pair manually"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "ICMP for troubleshooting"
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = ["0.0.0.0/0"]
  }

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

resource "aws_security_group" "partner_vpce" {
  name        = "${var.project_name}-partner-vpce-sg"
  description = "Allow partner instance to access the interface endpoint"
  vpc_id      = aws_vpc.partner.id

  ingress {
    description     = "HTTP from partner instance SG"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.partner_instance.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-partner-vpce-sg"
  }
}

resource "aws_instance" "partner" {
  ami                         = data.aws_ssm_parameter.al2023_ami.value
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.partner["az1"].id
  vpc_security_group_ids      = [aws_security_group.partner_instance.id]
  associate_public_ip_address = true

  user_data = <<-EOFUSERDATA
              #!/bin/bash
              dnf update -y
              dnf install -y curl
              echo "Partner instance ready" > /etc/motd
              EOFUSERDATA

  tags = {
    Name = "${var.project_name}-partner-instance"
  }
}

resource "aws_vpc_endpoint" "partner_to_workload" {
  vpc_id             = aws_vpc.partner.id
  service_name       = aws_vpc_endpoint_service.workload.service_name
  vpc_endpoint_type  = "Interface"
  subnet_ids         = [for s in aws_subnet.partner : s.id]
  security_group_ids = [aws_security_group.partner_vpce.id]
  private_dns_enabled = false

  tags = {
    Name = "${var.project_name}-partner-to-workload-vpce"
  }
}
