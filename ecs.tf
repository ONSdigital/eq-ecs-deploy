resource "aws_alb_target_group" "target_group" {
  name     = "${var.env}-${var.service_name}"
  port     = 80
  protocol = "HTTP"
  vpc_id   = "${var.vpc_id}"

  health_check = {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    interval            = 5
    timeout             = 2
    path                = "${var.healthcheck_path}"
  }

  tags {
    Environment = "${var.env}"
  }
}

resource "aws_alb_listener_rule" "listener_rule" {
  count        = "${var.dns_record_name == "" ? 1 : 0}"
  listener_arn = "${var.aws_alb_listener_arn}"
  priority     = "${var.listener_rule_priority}"

  action {
    type             = "forward"
    target_group_arn = "${aws_alb_target_group.target_group.arn}"
  }

  condition = [
    {
      field  = "host-header"
      values = ["${aws_route53_record.dns_record.name}"]
    },
    {
      field  = "path-pattern"
      values = ["${var.alb_listener_path_pattern}"]
    },
  ]
}

resource "aws_alb_listener_rule" "listener_rule_existing" {
  count        = "${var.dns_record_name == "" ? 0 : 1}"
  listener_arn = "${var.aws_alb_listener_arn}"
  priority     = "${var.listener_rule_priority}"

  action {
    type             = "forward"
    target_group_arn = "${aws_alb_target_group.target_group.arn}"
  }

  condition = [
    {
      field  = "host-header"
      values = ["${var.dns_record_name}"]
    },
    {
      field  = "path-pattern"
      values = ["${var.alb_listener_path_pattern}"]
    },
  ]
}

resource "aws_route53_record" "dns_record" {
  count   = "${var.dns_record_name == "" ? 1 : 0}"
  zone_id = "${data.aws_route53_zone.dns_zone.id}"
  name    = "${var.env}-${var.service_name}.${data.aws_route53_zone.dns_zone.name}"
  type    = "A"

  alias {
    name                   = "${data.aws_lb.eq.dns_name}"
    zone_id                = "${data.aws_lb.eq.zone_id}"
    evaluate_target_health = false
  }
}

data "template_file" "task" {
  template = "${file("${path.module}/task-definitions/task.json")}"

  vars = {
    "CONTAINER_REGISTRY"    = "${var.docker_registry}"
    "CONTAINER_NAME"        = "${var.container_name}"
    "CONTAINER_TAG"         = "${var.container_tag}"
    "CONTAINER_PORT"        = "${var.container_port}"
    "MEMORY_RESERVATION"    = "${var.container_memory_reservation}"
    "LOG_GROUP"             = "${join("-", list(var.env, var.service_name))}"
    "ENVIRONMENT_VARIABLES" = "${var.container_environment_variables}"
  }
}

resource "aws_ecs_task_definition" "task_definition" {
  family                = "${var.env}-${var.service_name}"
  container_definitions = "${data.template_file.task.rendered}"
  task_role_arn         = "${aws_iam_role.task_iam_role.arn}"
}

resource "aws_ecs_service" "service" {
  depends_on = [
    "aws_alb_target_group.target_group",
    "aws_alb_listener_rule.listener_rule",
    "aws_alb_listener_rule.listener_rule_existing",
  ]

  name                              = "${var.env}-${var.service_name}"
  cluster                           = "${data.aws_ecs_cluster.ecs-cluster.id}"
  task_definition                   = "${aws_ecs_task_definition.task_definition.family}"
  desired_count                     = "${var.application_min_tasks}"
  iam_role                          = "${aws_iam_role.service_iam_role.arn}"
  health_check_grace_period_seconds = "${var.healthcheck_grace_period_seconds}"

  ordered_placement_strategy {
    type  = "spread"
    field = "host"
  }

  load_balancer {
    target_group_arn = "${aws_alb_target_group.target_group.arn}"
    container_name   = "${var.container_name}"
    container_port   = "${var.container_port}"
  }

  lifecycle {
    ignore_changes = ["placement_strategy", "desired_count"]
  }
}

resource "aws_iam_role" "service_iam_role" {
  name = "${var.env}_iam_for_${var.service_name}"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": ["ecs.amazonaws.com", "ecs-tasks.amazonaws.com"]
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

data "aws_iam_policy_document" "policy_document" {
  "statement" = {
    "effect" = "Allow"

    "actions" = [
      "elasticloadbalancing:*",
    ]

    "resources" = [
      "*",
    ]
  }
}

resource "aws_iam_role_policy" "role_policy" {
  name   = "${var.env}_iam_for_${var.service_name}"
  role   = "${aws_iam_role.service_iam_role.id}"
  policy = "${data.aws_iam_policy_document.policy_document.json}"
}

resource "aws_cloudwatch_log_group" "log_group" {
  name = "${var.env}-${var.service_name}"

  tags {
    Environment = "${var.env}"
  }
}

output "service_address" {
  value = "https://${var.dns_record_name == "" ? aws_route53_record.dns_record.name : var.dns_record_name}"
}

resource "aws_iam_role" "task_iam_role" {
  name = "${var.env}_iam_for_${var.service_name}_task"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": ["ecs-tasks.amazonaws.com"]
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "role_policy_task" {
  count  = "${var.task_has_iam_policy ? 1 : 0}"
  name   = "${var.env}_iam_for_${var.service_name}_task"
  role   = "${aws_iam_role.task_iam_role.id}"
  policy = "${var.task_iam_policy_json}"
}
