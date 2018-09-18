data "template_file" "fargate_task" {
  count    = "${var.launch_type == "FARGATE" ? 1 : 0}"
  template = "${file("${path.module}/task-definitions/task.json")}"

  vars = {
    "ENV"                   = "${var.env}"
    "CONTAINER_REGISTRY"    = "${var.docker_registry}"
    "CONTAINER_NAME"        = "${var.container_name}"
    "CONTAINER_TAG"         = "${var.container_tag}"
    "CONTAINER_PORT"        = "${var.container_port}"
    "HOST_PORT"             = "${var.container_port}"
    "MEMORY_RESERVATION"    = "${var.container_memory_reservation}"
    "LOG_GROUP"             = "${join("-", list(var.env, var.service_name))}"
    "ENVIRONMENT_VARIABLES" = "${var.container_environment_variables}"
  }
}

resource "aws_ecs_task_definition" "fargate_task_definition" {
  count                 = "${var.launch_type == "FARGATE" ? 1 : 0}"
  family                = "${var.env}-${var.service_name}"
  container_definitions = "${data.template_file.fargate_task.rendered}"
  task_role_arn         = "${aws_iam_role.task_iam_role.arn}"
  execution_role_arn    = "${aws_iam_role.ecs_execution_iam_role.arn}"

  network_mode             = "awsvpc"
  requires_compatibilities = ["${var.launch_type}"]
  cpu                      = "${var.cpu_units}"
  memory                   = "${var.memory_units}"
}

resource "aws_ecs_service" "fargate_service" {
  count = "${var.launch_type == "FARGATE" ? 1 : 0}"

  depends_on = [
    "aws_alb_target_group.target_group",
    "aws_alb_listener_rule.listener_rule",
    "aws_alb_listener_rule.listener_rule_existing",
  ]

  name                              = "${var.env}-${var.service_name}"
  cluster                           = "${data.aws_ecs_cluster.ecs-cluster.id}"
  task_definition                   = "${aws_ecs_task_definition.fargate_task_definition.family}"
  desired_count                     = "${var.application_min_tasks}"
  health_check_grace_period_seconds = "${var.healthcheck_grace_period_seconds}"

  launch_type = "${var.launch_type}"

  load_balancer {
    target_group_arn = "${aws_alb_target_group.target_group.arn}"
    container_name   = "${var.container_name}"
    container_port   = "${var.container_port}"
  }

  network_configuration {
    subnets         = ["${var.ecs_subnet_ids}"]
    security_groups = ["${var.ecs_alb_security_group}"]
  }

  lifecycle {
    ignore_changes = ["placement_strategy", "desired_count"]
  }
}
