data "template_file" "task" {
  count    = "${var.launch_type == "EC2" ? 1 : 0}"
  template = "${file("${path.module}/task-definitions/task.json")}"

  vars = {
    "ENV"                   = "${var.env}"
    "CONTAINER_REGISTRY"    = "${var.docker_registry}"
    "CONTAINER_NAME"        = "${var.container_name}"
    "CONTAINER_TAG"         = "${var.container_tag}"
    "CONTAINER_PORT"        = "${var.container_port}"
    "HOST_PORT"             = "0"
    "MEMORY_RESERVATION"    = "${var.container_memory_reservation}"
    "LOG_GROUP"             = "${join("-", list(var.env, var.service_name))}"
    "ENVIRONMENT_VARIABLES" = "${var.container_environment_variables}"
  }
}

resource "aws_ecs_task_definition" "task_definition" {
  count                 = "${var.launch_type == "EC2" ? 1 : 0}"
  family                = "${var.env}-${var.service_name}"
  container_definitions = "${data.template_file.task.rendered}"
  task_role_arn         = "${aws_iam_role.task_iam_role.arn}"
  execution_role_arn    = "${aws_iam_role.ecs_execution_iam_role.arn}"

  network_mode             = "bridge"
  requires_compatibilities = ["${var.launch_type}"]
}

resource "aws_ecs_service" "service" {
  count = "${var.launch_type == "EC2" ? 1 : 0}"

  depends_on = [
    "aws_alb_target_group.target_group",
    "aws_alb_listener_rule.listener_rule",
    "aws_alb_listener_rule.listener_rule_auth",
  ]

  name                              = "${var.env}-${var.service_name}"
  cluster                           = "${data.aws_ecs_cluster.ecs-cluster.id}"
  task_definition                   = "${aws_ecs_task_definition.task_definition.family}"
  desired_count                     = "${var.application_min_tasks}"
  health_check_grace_period_seconds = "${var.healthcheck_grace_period_seconds}"

  launch_type = "${var.launch_type}"

  load_balancer {
    target_group_arn = "${aws_alb_target_group.target_group.arn}"
    container_name   = "${var.container_name}"
    container_port   = "${var.container_port}"
  }

  lifecycle {
    ignore_changes = ["placement_strategy", "desired_count"]
  }
}
