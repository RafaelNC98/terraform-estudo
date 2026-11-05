# =============================================================================
# CONFIGURACAO GERAL E REDE
# Define a regiao da AWS e encontra a VPC padrao e suas sub-redes.
# =============================================================================
provider "aws" {
  region = "us-east-1"
}

data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# =============================================================================
# GRUPOS DE SEGURANCA
# O ALB recebe HTTP publico; as instancias recebem HTTP somente do ALB.
# =============================================================================
resource "aws_security_group" "load_balancer" {
  name   = "teste-load-balancer"
  vpc_id = data.aws_vpc.default.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "instance" {
  name   = "teste_servidor"
  vpc_id = data.aws_vpc.default.id

  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.load_balancer.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# =============================================================================
# MODELO DAS INSTANCIAS EC2
# Define a AMI, o tipo de instancia e a instalacao do Apache.
# =============================================================================
resource "aws_launch_template" "web" {
  name_prefix   = "teste-servidor-"
  image_id      = "ami-0d97d7f07b25dd693"
  instance_type = "t3.micro"

  network_interfaces {
    associate_public_ip_address = true
    security_groups             = [aws_security_group.instance.id]
  }

  # Instala e inicia o Apache quando cada instancia e criada.
  user_data = base64encode(<<-EOF
    #!/bin/bash
    apt update -y
    apt install apache2 -y
    systemctl enable --now apache2
    echo "Hello World" > /var/www/html/index.html
  EOF
  )
}

# =============================================================================
# LOAD BALANCER (ALB)
# O ALB publico recebe requisicoes, verifica a saude e encaminha o trafego.
# =============================================================================
resource "aws_lb" "web" {
  name               = "teste-servidor-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.load_balancer.id]
  subnets            = data.aws_subnets.default.ids
}

resource "aws_lb_target_group" "web" {
  name     = "teste-servidor-web"
  port     = 80
  protocol = "HTTP"
  vpc_id   = data.aws_vpc.default.id

  health_check {
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 30
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

resource "aws_lb_listener" "web" {
  load_balancer_arn = aws_lb.web.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web.arn
  }
}

# =============================================================================
# AUTO SCALING GROUP (ASG)
# Mantem entre 2 e 4 instancias e registra-as no grupo de destino do ALB.
# =============================================================================
resource "aws_autoscaling_group" "web" {
  # Um prefixo permite criar um grupo substituto antes de remover o anterior.
  name_prefix               = "teste-servidor-"
  min_size                  = 2
  max_size                  = 4
  desired_capacity          = 2
  vpc_zone_identifier       = data.aws_subnets.default.ids
  target_group_arns         = [aws_lb_target_group.web.arn]
  health_check_type         = "ELB"
  health_check_grace_period = 300

  launch_template {
    id      = aws_launch_template.web.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "UbuntuTeste"
    propagate_at_launch = true
  }

  lifecycle {
    # Cria o grupo substituto antes de remover o atual, reduzindo indisponibilidade.
    create_before_destroy = true

    # Preserva a capacidade ajustada automaticamente pela politica de escala.
    ignore_changes = [desired_capacity]
  }
}

# =============================================================================
# POLITICA DE ESCALABILIDADE
# A AWS ajusta a quantidade de instancias para manter a CPU media em 50%.
# =============================================================================
resource "aws_autoscaling_policy" "cpu" {
  name                   = "teste-servidor-cpu"
  policy_type            = "TargetTrackingScaling"
  autoscaling_group_name = aws_autoscaling_group.web.name

  target_tracking_configuration {
    target_value = 50

    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
  }
}

# Consulta os IPs publicos das instancias em execucao pertencentes ao grupo.
data "aws_instances" "web" {
  filter {
    name   = "tag:aws:autoscaling:groupName"
    values = [aws_autoscaling_group.web.name]
  }

  filter {
    name   = "instance-state-name"
    values = ["running"]
  }
}

# =============================================================================
# SAIDAS
# Mostra o endereco do ALB e os IPs publicos das instancias em execucao.
# =============================================================================
output "load_balancer_url" {
  description = "URL publica do load balancer"
  value       = "http://${aws_lb.web.dns_name}"
}

output "public_ips" {
  description = "IPs publicos das instancias EC2 em execucao"
  value       = data.aws_instances.web.public_ips
}
