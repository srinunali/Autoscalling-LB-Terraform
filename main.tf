provider "aws" {
  region = "us-east-1"
}

resource "aws_vpc" "My-AutoScaling-VPC" {
  cidr_block = "12.0.0.0/16"
  

  tags = {
    Name = "My-AutoScaling-VPC"
  } 
    
}

resource "aws_subnet" "My-AutoScaling-Subnet-1" {
  vpc_id            = aws_vpc.My-AutoScaling-VPC.id
  cidr_block        = "12.0.1.0/24"
  availability_zone = "us-east-1a"  
    map_public_ip_on_launch = true

  tags = {
    Name = "My-AutoScaling-Subnet-1"
  }
}

resource "aws_subnet" "My-AutoScaling-Subnet-2" {
  vpc_id            = aws_vpc.My-AutoScaling-VPC.id
  cidr_block        = "12.0.2.0/24"
  availability_zone = "us-east-1b"
    map_public_ip_on_launch = true

  tags = {
    Name = "My-AutoScaling-Subnet-2"

  }
}


  resource "aws_internet_gateway" "My-AutoScaling-IGW" {
    vpc_id = aws_vpc.My-AutoScaling-VPC.id
    tags = {
      Name = "My-AutoScaling-IGW"
    }   

  }

  resource "aws_route_table" "name" {
    vpc_id = aws_vpc.My-AutoScaling-VPC.id

    route {
      cidr_block = "0.0.0.0/0"
      gateway_id = aws_internet_gateway.My-AutoScaling-IGW.id

      }
  }

  resource "aws_route_table_association" "My-AutoScaling-Subnet-1" {
    subnet_id      = aws_subnet.My-AutoScaling-Subnet-1.id
    route_table_id = aws_route_table.name.id
    
  }

  resource "aws_route_table_association" "My-AutoScaling-Subnet-2" {
    subnet_id      = aws_subnet.My-AutoScaling-Subnet-2.id
    route_table_id = aws_route_table.name.id
    
  }

  resource "aws_lb_target_group" "My-AutoScaling-TG" {
    name     = "My-AutoScaling-TG"
    port     = 80
    protocol = "HTTP"
    vpc_id   = aws_vpc.My-AutoScaling-VPC.id

    health_check {
      path                = "/"
      interval            = 30
      timeout             = 5
      healthy_threshold  = 2
      unhealthy_threshold = 2
    }

    tags = {
      Name = "My-AutoScaling-TG"
    }   
    
  }

  resource "aws_lb" "My-AutoScaling-LB" {
    name               = "My-AutoScaling-LB"
    internal           = false
    load_balancer_type = "application"
    security_groups    = [aws_security_group.My-AutoScaling-SG.id]
    subnets            = [aws_subnet.My-AutoScaling-Subnet-1.id, aws_subnet.My-AutoScaling-Subnet-2.id]


    tags = {
      Name = "My-AutoScaling-LB"
    }   
    
  }

  resource "aws_lb_listener" "My-AutoScaling-LB-Listener" {
    load_balancer_arn = aws_lb.My-AutoScaling-LB.arn
    port              = 80
    protocol          = "HTTP"

    default_action {
      type = "forward"
      target_group_arn = aws_lb_target_group.My-AutoScaling-TG.arn
    }

    tags = {
      Name = "My-AutoScaling-LB-Listener"
    }   
    
  }

    resource "aws_security_group" "My-AutoScaling-SG" {
        vpc_id = aws_vpc.My-AutoScaling-VPC.id
        name   = "My-AutoScaling-SG"
        description = "Allow HTTP  traffic"

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
        tags = {
            Name = "My-AutoScaling-SG"
        }

    }

    resource "aws_security_group" "My-AutoScaling-SG-SSH" {
        vpc_id = aws_vpc.My-AutoScaling-VPC.id
        name   = "My-AutoScaling-SG-SSH"
        description = "Allow SSH traffic"


        ingress {
        from_port   = 22
        to_port     = 22
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
        }



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
        tags = {
            Name = "My-AutoScaling-SG-SSH"
        }
    }

        resource "aws_launch_template" "My-AutoScaling-LC" {
        name          = "My-AutoScaling-LC"
        image_id      = "ami-084568db4383264d4" # Replace with your desired AMI ID
        instance_type = "t2.micro"
        key_name      = "MyKeyPair" # Replace with your key pair name
        network_interfaces {
            security_groups = [aws_security_group.My-AutoScaling-SG.id, aws_security_group.My-AutoScaling-SG-SSH.id]
        }

        user_data = base64encode(<<-EOF
            #!/bin/bash
            yum update -y
            yum install -y httpd
            systemctl start httpd
            systemctl enable httpd
            echo "<h1>Hello from Auto Scaling Group</h1>" > /var/www/html/index.html
            EOF 
            )

        lifecycle {
        create_before_destroy = true
        }       

       tags = {
        Name = "My-AutoScaling-LC"
        }

      
    }

    resource "aws_autoscaling_group" "My-AutoScaling-Group" {
        desired_capacity     = 2
        max_size             = 3
        min_size             = 1
        vpc_zone_identifier = [aws_subnet.My-AutoScaling-Subnet-1.id, aws_subnet.My-AutoScaling-Subnet-2.id]
        launch_template {
            id      = aws_launch_template.My-AutoScaling-LC.id
            version = "$Latest"
        }
        health_check_type = "ELB"   


        tag {
            key                 = "Name"
            value               = "My-AutoScaling-Instance"
            propagate_at_launch = true
        }

        health_check_grace_period = 20
      
    }

    resource "aws_autoscaling_attachment" "My-AutoScaling-Attachment" {
        autoscaling_group_name = aws_autoscaling_group.My-AutoScaling-Group.name
        lb_target_group_arn    = aws_lb_target_group.My-AutoScaling-TG.arn

      
    }

    resource "aws_autoscaling_policy" "My-AutoScaling-Policy" {
        name                   = "My-AutoScaling-Policy"
        scaling_adjustment      = 1
        adjustment_type        = "ChangeInCapacity"
        cooldown               = 300
        autoscaling_group_name = aws_autoscaling_group.My-AutoScaling-Group.name

          
        
    }   

    resource "aws_autoscaling_policy" "My-AutoScaling-Policy-Scale-In" {
        name                   = "My-AutoScaling-Policy-Scale-In"
        scaling_adjustment      = -1
        adjustment_type        = "ChangeInCapacity"
        cooldown               = 300
        autoscaling_group_name = aws_autoscaling_group.My-AutoScaling-Group.name  
        
    }   






    

