# Criar VPC e dependencias
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.0.0"

  name = "wordpress-vpc"
  cidr = "10.0.0.0/16"

  azs             = ["us-east-1a", "us-east-1b"]
  public_subnets  = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnets = ["10.0.101.0/24", "10.0.102.0/24"]

  enable_nat_gateway = true
  single_nat_gateway = true
  enable_dns_hostnames = true
  enable_dns_support   = true

}

# Security Group das EC2
resource "aws_security_group" "ec2_sg" {
  name_prefix = "ec2-sg"
  description = "Security group para associar nas instancias EC2"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description = "Permite trafego HTTP vindo do ALB"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }

  ingress {
    description = "Permite trafego HTTPS vindo do ALB"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }

  egress {
    description      = "Permite trafego de saida para a internet"
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  tags = {
    Name = "ec2-sg"
  }
}

# Security Group do RDS e EFS
resource "aws_security_group" "rds-efs_sg" {
  name_prefix = "rds_fs-sg"
  description = "Habilita trafego para o RDS e EFS"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    description     = "Permite trafego MySQL vindo da EC2"
    security_groups = [aws_security_group.ec2_sg.id]
  }

  ingress {
    from_port   = 2049 
    to_port     = 2049
    protocol    = "tcp"
    description = "Permite trafego do EFS vindo da EC2"
    security_groups = [aws_security_group.ec2_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "rds-efs-sg"
  }
}

# Security Group do Load Balancer
resource "aws_security_group" "alb_sg" {
  name_prefix = "alb-sg"
  description = "Security group para acesso a internet do ALB"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description = "Permite entrada de trafego HTTP vindo da internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Permite entrada de trafego HTTPS vindo da internet"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "alb-sg"
  }
}

# Associa o grupo de subnets privadas que ira ser associado ao RDS
resource "aws_db_subnet_group" "main" {
  name       = "my-db-subnet-group"
  subnet_ids = [module.vpc.private_subnets[0], module.vpc.private_subnets[1]]
  tags = {
    Name = "My DB Subnet Group"
  }
}

# Criação RDS
resource "aws_db_instance" "default" {
  engine                 = "mysql"
  engine_version         = "8.0"
  instance_class         = "db.t3.micro"
  allocated_storage      = 20
  db_name                = "wordpress_db"
  username               = var.db_username
  password               = var.db_password
  parameter_group_name   = "default.mysql8.0"
  skip_final_snapshot    = true 
  publicly_accessible    = false
  multi_az = false

  # Network
  db_subnet_group_name = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds-efs_sg.id]

}

# Cria o EFS File System
resource "aws_efs_file_system" "wordpress_efs" {
  creation_token = "wordpress-efs-token"

  tags = {
    Name = "wordpress-efs"
  }
}

# Cria os Mount Targets
resource "aws_efs_mount_target" "efs_mount_target" {
  for_each = { for index, subnet_id in module.vpc.private_subnets : index => subnet_id }
  file_system_id  = aws_efs_file_system.wordpress_efs.id
  subnet_id       = each.value
  security_groups = [aws_security_group.rds-efs_sg.id]
}

# Launch Template para o Auto Scaling Group
resource "aws_launch_template" "wordpress_lt" {
  name_prefix   = "wordpress-lt-"
  image_id      = "ami-0360c520857e3138f"
  instance_type = "t2.micro"

  # Associa o Security Group EC2
  vpc_security_group_ids = [aws_security_group.ec2_sg.id]

  user_data = base64encode(templatefile("${path.module}/userdata.sh", {
    efs_id = aws_efs_file_system.wordpress_efs.id
    db_host = aws_db_instance.default.address
    db_user = aws_db_instance.default.username
    db_password = var.db_password
    db_name = aws_db_instance.default.db_name
  }))

  # Adiciona tags
  tag_specifications {
    resource_type = "instance"
    tags = var.default_tags
  }

  tag_specifications {
    resource_type = "volume"
    tags = var.default_tags
  }
}

# Cria o Load Balancer
resource "aws_lb" "wordpress_alb" {
  name               = "wordpress-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = module.vpc.public_subnets

  tags = {
    Name = "wordpress-alb"
  }
}

# Cria o Target Group
resource "aws_lb_target_group" "wordpress_tg" {
  name     = "wordpress-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = module.vpc.vpc_id

  health_check {
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200,302,403"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }

  stickiness {
    type            = "lb_cookie"
    enabled         = true
    cookie_duration = 86400
  }

  tags = {
    Name = "wordpress-target-group"
  }
}

# Cria o Listener
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.wordpress_alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.wordpress_tg.arn
  }
}

# Cria o Auto Scaling Group
resource "aws_autoscaling_group" "wordpress_asg" {
  name                = "wordpress-asg"
  desired_capacity    = 2
  min_size            = 1 
  max_size            = 4 

  vpc_zone_identifier = module.vpc.private_subnets
  target_group_arns   = [aws_lb_target_group.wordpress_tg.arn]

  # Usa o Launch Template que já definimos
  launch_template {
    id      = aws_launch_template.wordpress_lt.id
    version = aws_launch_template.wordpress_lt.latest_version
  }

  # Adiciona tags a todas as instâncias que forem criadas por ele
  dynamic "tag" {
    for_each = var.default_tags
    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }
}

# Política de Escalonamento para o Auto Scaling Group (baseada em CPU)
resource "aws_autoscaling_policy" "cpu_scaling_policy" {
  name                   = "wordpress-cpu-scaling-policy"
  autoscaling_group_name = aws_autoscaling_group.wordpress_asg.name
  policy_type            = "TargetTrackingScaling"

  # Configuração do Target Tracking
  target_tracking_configuration {
    # Define o valor alvo que o ASG tentará manter
    target_value = 50.0 # Alvo de 50% de uso de CPU

    # Define a métrica pré-definida que será monitorada
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
  }
}