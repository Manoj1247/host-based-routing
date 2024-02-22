resource "aws_vpc" "my_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "my-vpc-hbr"
  }
}

resource "aws_subnet" "subnet_a" {
  vpc_id            = aws_vpc.my_vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-east-1a"
}

resource "aws_subnet" "subnet_b" {
  vpc_id            = aws_vpc.my_vpc.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "us-east-1b"
}

resource "aws_security_group" "lb_sg" {
  vpc_id = aws_vpc.my_vpc.id
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::0/0"]
  }
}

resource "aws_security_group" "website_security_group" {
  name        = "website-security-group"
  description = "Security group for Website A EC2 instance"
  vpc_id      = aws_vpc.my_vpc.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = -1
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::0/0"]
  }

}

resource "aws_instance" "website_a" {
  ami                         = "ami-0440d3b780d96b29d"
  instance_type               = "t2.micro"
  subnet_id                   = aws_subnet.subnet_a.id
  associate_public_ip_address = true
  security_groups             = [aws_security_group.website_security_group.id]
  user_data                   = <<-EOF
              #!/bin/bash
              #install httpd (Linux 2 version)
              yum update -y
              yum install -y httpd.x86_64
              systemctl start httpd.service
              systemctl enable httpd.service
              echo "<html><body><h1>Welcome to Website A1</h1></body></html>" > /var/www/html/index.html
              EOF
}

resource "aws_instance" "website_b" {
  ami                         = "ami-0440d3b780d96b29d"
  instance_type               = "t2.micro"
  subnet_id                   = aws_subnet.subnet_b.id
  associate_public_ip_address = true
  security_groups             = [aws_security_group.website_security_group.id]
  user_data                   = <<-EOF
              #!/bin/bash
              #install httpd (Linux 2 version)
              yum update -y
              yum install -y httpd.x86_64
              systemctl start httpd.service
              systemctl enable httpd.service
              echo "<html><body><h1>Welcome to Website B1</h1></body></html>" > /var/www/html/index.html
              EOF
}

resource "aws_route53_record" "hbr-a" {
  zone_id = "Z03619852ATAGI2UXNAT7"
  name    = "weba"
  type    = "A"
  alias {
    name                   = aws_lb.my_lb.dns_name
    zone_id                = aws_lb.my_lb.zone_id
    evaluate_target_health = true
  }

}

resource "aws_route53_record" "hbr-b" {
  zone_id = "Z03619852ATAGI2UXNAT7"
  name    = "webb"
  type    = "A"
  alias {
    name                   = aws_lb.my_lb.dns_name
    zone_id                = aws_lb.my_lb.zone_id
    evaluate_target_health = true
  }

}

resource "aws_lb" "my_lb" {
  name                       = "my-lb"
  internal                   = false
  load_balancer_type         = "application"
  security_groups            = [aws_security_group.lb_sg.id]
  enable_deletion_protection = false

  enable_cross_zone_load_balancing = true
  idle_timeout                     = 60
  subnets                          = [aws_subnet.subnet_a.id, aws_subnet.subnet_b.id]
  enable_http2                     = true
}

resource "aws_lb_target_group" "target_group_weba" {
  name        = "target-group-weba"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = aws_vpc.my_vpc.id
  target_type = "instance"
}

resource "aws_lb_target_group" "target_group_webb" {
  name        = "target-group-webb"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = aws_vpc.my_vpc.id
  target_type = "instance"
}

resource "aws_lb_target_group_attachment" "attachment_a" {
  target_group_arn = aws_lb_target_group.target_group_weba.arn
  target_id        = aws_instance.website_a.id
}

resource "aws_lb_target_group_attachment" "attachment_b" {
  target_group_arn = aws_lb_target_group.target_group_webb.arn
  target_id        = aws_instance.website_b.id
}

resource "aws_lb_listener" "listener" {
  load_balancer_arn = aws_lb.my_lb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "fixed-response"
    fixed_response {
      content_type = "text/plain"
      status_code  = "200"
      message_body = "No web page found"
    }
  }
}

resource "aws_lb_listener_rule" "rule_weba" {
  listener_arn = aws_lb_listener.listener.arn
  priority     = 100

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.target_group_weba.arn
  }

  condition {
    host_header {
      values = ["weba.r53.manojkalaganti.com"]
    }
  }
}


resource "aws_lb_listener_rule" "rule_webb" {
  listener_arn = aws_lb_listener.listener.arn
  priority     = 200

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.target_group_webb.arn
  }

  condition {
    host_header {
      values = ["webb.r53.manojkalaganti.com"]
    }
  }
}


resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.my_vpc.id
}

resource "aws_route" "internet" {
  route_table_id         = aws_vpc.my_vpc.main_route_table_id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.main.id
}




