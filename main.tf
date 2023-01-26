data "aws_ecr_repository" "project_ecr_repo" {
  name = "project-ecr-repo"
}


resource "aws_ecs_cluster" "project_cluster" {
  name = "project-cluster"
}
# Looks like we do not need to specify the capacity provider strategy for the cluster, we can specify it in the service
#resource "aws_ecs_cluster_capacity_providers" "spot" {
#  cluster_name = aws_ecs_cluster.project_cluster.name
#
#  capacity_providers = ["FARGATE_SPOT"]
#
#  default_capacity_provider_strategy {
#    capacity_provider = "FARGATE_SPOT"
#    weight            = 1
#    base              = 0
#  }
#}

resource "aws_ecs_service" "project_service" {
  name            = "project-service"
  cluster         = aws_ecs_cluster.project_cluster.id
  task_definition = aws_ecs_task_definition.webapp_task.arn
  desired_count   = 3
  capacity_provider_strategy {
    capacity_provider = "FARGATE_SPOT"
    weight            = 1
  }
  network_configuration {
    subnets          = ["${aws_subnet.public_1.id}", "${aws_subnet.public_2.id}"]
    assign_public_ip = true
  }
}

resource "aws_ecs_task_definition" "webapp_task" {
  family                   = "webapp_task"
  container_definitions    = <<DEFINITION
  [
    {
    "name": "webapp_task",
    "image": "httpd:2.4",
    "portMappings": [
      {
        "containerPort": 80,
        "hostPort": 80,
        "protocol": "tcp"
      }
    ],
    "essential": true,
    "entryPoint": [
      "sh",
      "-c"
    ],
    "command": [
      "/bin/sh -c \"echo '<html> <head> <title>Amazon ECS Sample App</title> <style>body {margin-top: 40px; background-color: #333;} </style> </head><body> <div style=color:white;text-align:center> <h1>Amazon ECS Sample App</h1> <h2>Congratulations!</h2> <p>Your application is now running on a container in Amazon ECS.</p> </div></body></html>' >  /usr/local/apache2/htdocs/index.html && httpd-foreground\""
    ]
  }
  ]
  DEFINITION
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  memory                   = 512
  cpu                      = 256
  execution_role_arn       = aws_iam_role.ecsTaskExecutionRole.arn
}

data "aws_iam_policy_document" "ecs-assume-role-policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ecsTaskExecutionRole" {
  name               = "ecsTaskExecutionRole"
  assume_role_policy = data.aws_iam_policy_document.ecs-assume-role-policy.json
}

resource "aws_iam_role_policy_attachment" "ecsTaskExecutionRole_policy" {
  role       = aws_iam_role.ecsTaskExecutionRole.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}