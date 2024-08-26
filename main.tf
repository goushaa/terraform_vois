provider "aws" {
  region = "us-east-1"
}

terraform {
  backend "s3" {
    bucket         = "kady-tf-backend"     
    key            = "terraform.tfstate"
    region         = "us-east-1"               
    dynamodb_table = "kady-tf-backend"        
    encrypt        = true                      
  }
}

# VPC & SUBNETS & ROUTES

resource "aws_vpc" "kady_vpc" {
  cidr_block = "172.74.0.0/16"
  tags = {
    Name = "kady-vpc"
  }
}

resource "aws_internet_gateway" "kady_igw" {
  vpc_id = aws_vpc.kady_vpc.id
  tags = {
    Name = "kady-igw"
  }
}

resource "aws_subnet" "kady_public_subnet_1" {
  vpc_id                  = aws_vpc.kady_vpc.id
  cidr_block              = "172.74.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true
  tags = {
    Name = "kady-public-subnet-1"
  }
}

resource "aws_subnet" "kady_public_subnet_2" {
  vpc_id                  = aws_vpc.kady_vpc.id
  cidr_block              = "172.74.2.0/24"
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = true
  tags = {
    Name = "kady-public-subnet-2"
  }
}

resource "aws_route_table" "kady_public_route" {
  vpc_id = aws_vpc.kady_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.kady_igw.id
  }

  tags = {
    Name = "kady-public-route"
  }
}

resource "aws_route_table_association" "kady_public_rt_assoc_1" {
  subnet_id      = aws_subnet.kady_public_subnet_1.id
  route_table_id = aws_route_table.kady_public_route.id
}

resource "aws_route_table_association" "kady_public_rt_assoc_2" {
  subnet_id      = aws_subnet.kady_public_subnet_2.id
  route_table_id = aws_route_table.kady_public_route.id
}

# Security Groups & Role
resource "aws_security_group" "kady_sg1" {
  vpc_id = aws_vpc.kady_vpc.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 8080
    to_port     = 8080
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
    Name = "kady-sg1"
  }
}

resource "aws_security_group" "kady_sg2" {
  vpc_id = aws_vpc.kady_vpc.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 3000
    to_port     = 3000
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
    Name = "kady-sg2"
  }
}

resource "aws_iam_role" "kady_ec2_role" {
  name = "kady-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_policy" "kady_ecr_policy" {
  name = "kady-ecr-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:BatchCheckLayerAvailability"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = "ecr:GetAuthorizationToken"
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "kady_ec2_policy_attach" {
  role       = aws_iam_role.kady_ec2_role.name
  policy_arn = aws_iam_policy.kady_ecr_policy.arn
}

# EC2 Instances

resource "aws_instance" "kady_vm1" {
  ami           = "ami-04a81a99f5ec58529"
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.kady_public_subnet_1.id
  vpc_security_group_ids = [aws_security_group.kady_sg1.id]
  iam_instance_profile = aws_iam_instance_profile.kady_instance_profile.name

  tags = {
    Name = "kadyVM1"
  }

  user_data = <<-EOF
              #!/bin/bash
              apt-get update
              apt-get install -y docker.io docker-compose 
              apt update
              apt install unzip
              curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
              unzip awscliv2.zip
              ./aws/install

              

              # Ensure Docker is running
              systemctl start docker
              systemctl enable docker

              # Create a Docker group if it does not exist
              groupadd docker || true

              # Add the ubuntu user to the Docker group
              usermod -aG docker ubuntu
              newgrp docker

              docker run -d -p 80:80 -e MESSAGE="Hello from kadyVM1" goushaa/kady-nginx

              # Login to ECR
              aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin 851725310572.dkr.ecr.us-east-1.amazonaws.com # Change account id
              EOF
}

resource "aws_instance" "kady_vm2" {
  ami           = "ami-04a81a99f5ec58529"
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.kady_public_subnet_2.id
  vpc_security_group_ids = [aws_security_group.kady_sg2.id]
  iam_instance_profile = aws_iam_instance_profile.kady_instance_profile.name

  tags = {
    Name = "kadyVM2"
  }

  user_data = <<-EOF
              #!/bin/bash
              apt-get update
              apt-get install -y docker.io docker-compose
              apt update
              apt install unzip
              curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
              unzip awscliv2.zip
              ./aws/install

              # Ensure Docker is running
              systemctl start docker
              systemctl enable docker

              # Create a Docker group if it does not exist
              groupadd docker || true

              # Add the ubuntu user to the Docker group
              usermod -aG docker ubuntu
              newgrp docker

              docker run -d -p 80:80 -e MESSAGE="Hello from kadyVM2" goushaa/kady-nginx

              # Login to ECR
              aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin 851725310572.dkr.ecr.us-east-1.amazonaws.com # Change account id          
              EOF
}

resource "aws_iam_instance_profile" "kady_instance_profile" {
  name = "kady-instance-profile"
  role = aws_iam_role.kady_ec2_role.name
}


# Load Balancer
resource "aws_lb" "kady_alb" {
  name               = "kady-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.kady_sg1.id, aws_security_group.kady_sg2.id]
  subnets            = [aws_subnet.kady_public_subnet_1.id, aws_subnet.kady_public_subnet_2.id]

  enable_deletion_protection = false
  enable_cross_zone_load_balancing = true
  enable_http2 = true
  idle_timeout = 60

  tags = {
    Name = "kady-alb"
  }
}

resource "aws_lb_target_group" "kady_target_group" {
  name     = "kady-target-group"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.kady_vpc.id

  health_check {
    path                = "/"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 3
    unhealthy_threshold = 3
  }

  tags = {
    Name = "kady-target-group"
  }
}


resource "aws_lb_target_group" "kady_target_group_8080" {
  name     = "kady-target-group-8080"
  port     = 8080
  protocol = "HTTP"
  vpc_id   = aws_vpc.kady_vpc.id

  health_check {
    path                = "/"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 3
    unhealthy_threshold = 3
  }

  tags = {
    Name = "kady-target-group-8080"
  }
}

resource "aws_lb_target_group" "kady_target_group_3000" {
  name     = "kady-target-group-3000"
  port     = 3000
  protocol = "HTTP"
  vpc_id   = aws_vpc.kady_vpc.id

  health_check {
    path                = "/"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 3
    unhealthy_threshold = 3
  }

  tags = {
    Name = "kady-target-group-3000"
  }
}

resource "aws_lb_listener" "kady_listener" {
  load_balancer_arn = aws_lb.kady_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.kady_target_group.arn
  }
}

resource "aws_lb_listener" "kady_listener_8080" {
  load_balancer_arn = aws_lb.kady_alb.arn
  port              = 8080
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.kady_target_group_8080.arn
  }
}

resource "aws_lb_listener" "kady_listener_3000" {
  load_balancer_arn = aws_lb.kady_alb.arn
  port              = 3000
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.kady_target_group_3000.arn
  }
}

# Register Targets with Target Group for port 8080
resource "aws_lb_target_group_attachment" "kady_vm1_attachment_8080" {
  target_group_arn = aws_lb_target_group.kady_target_group_8080.arn
  target_id        = aws_instance.kady_vm1.id
  port             = 8080
}

# Register Targets with Target Group for port 3000
resource "aws_lb_target_group_attachment" "kady_vm2_attachment_3000" {
  target_group_arn = aws_lb_target_group.kady_target_group_3000.arn
  target_id        = aws_instance.kady_vm2.id
  port             = 3000
}

# Register Targets with Target Group
resource "aws_lb_target_group_attachment" "kady_vm1_attachment" {
  target_group_arn = aws_lb_target_group.kady_target_group.arn
  target_id        = aws_instance.kady_vm1.id
  port             = 80
}

resource "aws_lb_target_group_attachment" "kady_vm2_attachment" {
  target_group_arn = aws_lb_target_group.kady_target_group.arn
  target_id        = aws_instance.kady_vm2.id
  port             = 80
}

#ECR Repos
resource "aws_ecr_repository" "kady_jenkins" {
  name = "kady-jenkins"

  tags = {
    Name = "kady-jenkins"
  }
}

resource "aws_ecr_repository" "kady_nginx" {
  name = "kady-nodejs"

  tags = {
    Name = "kady-nodejs"
  }
}

resource "aws_ecr_repository" "kady_mysql" {
  name = "kady-mysql"

  tags = {
    Name = "kady-mysql"
  }
}
