resource "aws_alb_target_group" "target_group" {
  name                 = "${var.env}-${var.service_name}"
  port                 = 80
  protocol             = "HTTP"
  vpc_id               = "${var.vpc_id}"
  deregistration_delay = 20
  target_type          = "${var.launch_type == "EC2" ? "instance" : "ip"}"

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

resource "aws_iam_role" "ecs_execution_iam_role" {
  name = "${var.env}-iam-for-${var.service_name}-execution"

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

resource "aws_iam_role_policy" "ecs_execution_role_policy" {
  name   = "${var.env}-iam-for-${var.service_name}-execution"
  role   = "${aws_iam_role.ecs_execution_iam_role.id}"
  policy = "${data.aws_iam_policy_document.ecs_execution_service_policy_document.json}"
}

data "aws_iam_policy_document" "ecs_execution_service_policy_document" {
  "statement" = {
    "effect" = "Allow"

    "actions" = [
      "elasticloadbalancing:*",
    ]

    "resources" = [
      "*",
    ]
  }

  "statement" = {
    "effect" = "Allow"

    "actions" = [
      "ecr:GetAuthorizationToken",
      "ecr:BatchGetImage",
      "ecr:GetDownloadUrlForLayer",
    ]

    "resources" = [
      "*",
    ]
  }

  "statement" = {
    "effect" = "Allow"

    "actions" = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]

    "resources" = [
      "*",
    ]
  }
}
