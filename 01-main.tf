### NETWORKING RESOURCES ###

resource "aws_vpc" "main" {
  cidr_block = var.cidr
  tags = {
      "Name" = "${var.stage}-vpc"
      "Stage" = "${var.stage}"
  }
}
 
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags = {
      "Name" = "${var.stage}-igw"
      "Stage" = "${var.stage}"
  }
}
 
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(var.cidr, 2, 1)
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true
  tags = {
      "Name" = "${var.stage}-public-subnet-1"
      "Stage" = "${var.stage}"
  }
}

resource "aws_subnet" "public2" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(var.cidr, 2, 2)
  availability_zone       = data.aws_availability_zones.available.names[1]
  map_public_ip_on_launch = true
  tags = {
      "Name" = "${var.stage}-public-subnet-2"
      "Stage" = "${var.stage}"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  tags = {
      "Name" = "${var.stage}-public-route-table"
      "Stage" = "${var.stage}"
  }
}
 
resource "aws_route" "public" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.main.id
}
 
resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public2" {
  subnet_id      = aws_subnet.public2.id
  route_table_id = aws_route_table.public.id
}

### Security Groups ###

resource "aws_security_group" "alb" {
  name   = "${var.stage}-alb-sg"
  vpc_id = aws_vpc.main.id
 
  ingress {
   protocol         = "tcp"
   from_port        = 80
   to_port          = 80
   cidr_blocks      = ["0.0.0.0/0"]
   ipv6_cidr_blocks = ["::/0"]
  }
 
  ingress {
   protocol         = "tcp"
   from_port        = 443
   to_port          = 443
   cidr_blocks      = ["0.0.0.0/0"]
   ipv6_cidr_blocks = ["::/0"]
  }
 
  egress {
   protocol         = "-1"
   from_port        = 0
   to_port          = 0
   cidr_blocks      = ["0.0.0.0/0"]
   ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
      "Name" = "${var.stage}-alb-sg"
      "Stage" = "${var.stage}"
  }
}

resource "aws_security_group" "ecs_tasks" {
  name   = "${var.stage}-ecs-sg"
  vpc_id = aws_vpc.main.id
 
  ingress {
   protocol         = "tcp"
   from_port        = var.container_port
   to_port          = var.container_port
   cidr_blocks      = ["0.0.0.0/0"]
   ipv6_cidr_blocks = ["::/0"]
  }
 
  egress {
   protocol         = "-1"
   from_port        = 0
   to_port          = 0
   cidr_blocks      = ["0.0.0.0/0"]
   ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
      "Name" = "${var.stage}-ecs-sg"
      "Stage" = "${var.stage}"
  }
}

### ECS Cluster Resources ###

resource "aws_ecs_cluster" "main" {
  name = "${var.stage}-my-ecs-cluster"
  tags = {
      "Name" = "${var.stage}-my-ecs-cluster"
      "Stage" = "${var.stage}"
  }
}


resource "aws_ecs_task_definition" "main" {
  family = "${var.stage}-my-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = 256
  memory                   = 512
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_task_role.arn
  container_definitions = jsonencode([{
   name        = "my-container"
   image       = var.container_image
   essential   = true
   portMappings = [{
     protocol      = "tcp"
     containerPort = 80
     hostPort      = 80
   }]
  }])
  tags = {
      "Name" = "${var.stage}-my-task"
      "Stage" = "${var.stage}"
  }
}

resource "aws_ecs_service" "main" {
 name                               = "${var.stage}-my-service"
 cluster                            = aws_ecs_cluster.main.id
 task_definition                    = aws_ecs_task_definition.main.arn
 desired_count                      = var.desired_count
 deployment_minimum_healthy_percent = 50
 deployment_maximum_percent         = 200
 launch_type                        = "FARGATE"
 scheduling_strategy                = "REPLICA"
 
 network_configuration {
   security_groups  = [aws_security_group.ecs_tasks.id]
   subnets          = [aws_subnet.public.id, aws_subnet.public2.id]
   assign_public_ip = true
 }
 
 load_balancer {
   target_group_arn = aws_alb_target_group.main.arn
   container_name   = "my-container"
   container_port   = var.container_port
 }
 
 lifecycle {
   ignore_changes = [task_definition, desired_count]
 }
  tags = {
      "Name" = "${var.stage}-my-service"
      "Stage" = "${var.stage}"
  }
}

### IAM Resources ###

resource "aws_iam_role" "ecs_task_role" {
  name = "${var.stage}-ecsTaskRole"
 
  assume_role_policy = <<EOF
{
 "Version": "2012-10-17",
 "Statement": [
   {
     "Action": "sts:AssumeRole",
     "Principal": {
       "Service": "ecs-tasks.amazonaws.com"
     },
     "Effect": "Allow",
     "Sid": ""
   }
 ]
}
EOF
  tags = {
      "Name" = "${var.stage}-ecsTaskRole"
      "Stage" = "${var.stage}"
  }
}
 
resource "aws_iam_policy" "ecs_task_policy" {
  name        = "${var.stage}-ecs_task_policy"
  description = "Policy that allows the task to perform certain AWS actions"
 
 policy = "${file("iam/ecs_policy.json")}"
  tags = {
      "Name" = "${var.stage}-ecs_task_policy"
      "Stage" = "${var.stage}"
  }
}
 
resource "aws_iam_role_policy_attachment" "ecs-task-role-policy-attachment" {
  role       = aws_iam_role.ecs_task_role.name
  policy_arn = aws_iam_policy.ecs_task_policy.arn
}

resource "aws_iam_role" "ecs_task_execution_role" {
  name = "${var.stage}-ecsTaskExecutionRole"
 
  assume_role_policy = <<EOF
{
 "Version": "2012-10-17",
 "Statement": [
   {
     "Action": "sts:AssumeRole",
     "Principal": {
       "Service": "ecs-tasks.amazonaws.com"
     },
     "Effect": "Allow",
     "Sid": ""
   }
 ]
}
EOF
  tags = {
      "Name" = "${var.stage}-ecsTaskExecutionRole"
      "Stage" = "${var.stage}"
  }
}
 
resource "aws_iam_role_policy_attachment" "ecs-task-execution-role-policy-attachment" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

### Load Balancer ###

resource "aws_lb" "main" {
  name               = "${var.stage}-my-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = [aws_subnet.public.id, aws_subnet.public2.id]
 
  enable_deletion_protection = false
  tags = {
      "Name" = "${var.stage}-my-alb"
      "Stage" = "${var.stage}"
  }
}
 
resource "aws_alb_target_group" "main" {
  name        = "${var.stage}-my-target-group"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip"
 
  health_check {
   healthy_threshold   = "3"
   interval            = "30"
   protocol            = "HTTP"
   matcher             = "200"
   timeout             = "3"
   path                = "/"
   unhealthy_threshold = "2"
  }
  tags = {
      "Name" = "${var.stage}-my-target-group"
      "Stage" = "${var.stage}"
  }
}

resource "aws_alb_listener" "http" {
  load_balancer_arn = aws_lb.main.id
  port              = 80
  protocol          = "HTTP"
 
  default_action {
    target_group_arn = aws_alb_target_group.main.id
    type             = "forward"
  }
}

