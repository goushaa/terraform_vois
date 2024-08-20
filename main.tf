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

resource "aws_security_group" "kady_sg" {
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

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "kady-sg"
  }
}

resource "aws_instance" "kady_vm1" {
  ami           = "ami-04a81a99f5ec58529"
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.kady_public_subnet_1.id
  vpc_security_group_ids = [aws_security_group.kady_sg.id]

  tags = {
    Name = "kadyVM1"
  }

  user_data = <<-EOF
              #!/bin/bash
              apt-get update
              apt-get install -y nginx docker.io docker-compose

              # Ensure Docker is running
              systemctl start docker
              systemctl enable docker

              # Create a Docker group if it does not exist
              groupadd docker || true

              # Add the ubuntu user to the Docker group
              usermod -aG docker ubuntu

              # Restart Docker to ensure group membership is applied
              systemctl restart docker

              # Start and enable Nginx
              systemctl start nginx
              systemctl enable nginx

              # Create a simple HTML page
              echo "<h1>Hello from Kady1</h1>" > /var/www/html/index.html
              EOF
}

resource "aws_instance" "kady_vm2" {
  ami           = "ami-04a81a99f5ec58529"
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.kady_public_subnet_2.id
  vpc_security_group_ids = [aws_security_group.kady_sg.id]

  tags = {
    Name = "kadyVM2"
  }

  user_data = <<-EOF
              #!/bin/bash
              apt-get update
              apt-get install -y nginx docker.io docker-compose

              # Ensure Docker is running
              systemctl start docker
              systemctl enable docker

              # Create a Docker group if it does not exist
              groupadd docker || true

              # Add the ubuntu user to the Docker group
              usermod -aG docker ubuntu

              # Restart Docker to ensure group membership is applied
              systemctl restart docker

              # Start and enable Nginx
              systemctl start nginx
              systemctl enable nginx
              
              # Create a simple HTML page
              echo "<h1>Hello from Kady2</h1>" > /var/www/html/index.html
              EOF
}

# Create a Load Balancer
resource "aws_lb" "kady_alb" {
  name               = "kady-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.kady_sg.id]
  subnets            = [aws_subnet.kady_public_subnet_1.id, aws_subnet.kady_public_subnet_2.id]

  enable_deletion_protection = false
  enable_cross_zone_load_balancing = true
  enable_http2 = true
  idle_timeout = 60

  tags = {
    Name = "kady-alb"
  }
}

# Create a Target Group
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

# Create an ALB Listener
resource "aws_lb_listener" "kady_listener" {
  load_balancer_arn = aws_lb.kady_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.kady_target_group.arn
  }
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

resource "aws_ecr_repository" "kady_ecr" {
  name = "kady-ecr"

  tags = {
    Name = "kady-ecr"
  }
}
