resource "null_resource" "aws_alb_exists" {
  # Fake resource to add a dependency on the ALB.
  # https://github.com/hashicorp/terraform/issues/12634
  triggers {
    alb_name = "${var.aws_alb_arn}"
  }
}

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

  # Fake dependency to avoid error with target group
  depends_on = ["null_resource.aws_alb_exists"]

  tags {
    Environment = "${var.env}"
  }
}

output "target_group_arn" {
  value = "${aws_alb_target_group.target_group.arn}"
}

resource "aws_alb_listener_rule" "listener_rule" {
  count        = "${var.auth_issuer == "" && var.aws_alb_use_host_header ? length(var.alb_listener_path_patterns) : 0}"
  listener_arn = "${var.aws_alb_listener_arn}"
  priority     = "${var.listener_rule_priority + count.index}"

  action {
    type             = "forward"
    target_group_arn = "${aws_alb_target_group.target_group.arn}"
  }

  condition = [
    {
      field  = "host-header"
      values = ["${var.listener_rule_host_header == "" ? coalescelist(aws_route53_record.dns_record.*.name, list(var.dns_record_name)) : var.listener_rule_host_header}"]
    },
    {
      field  = "path-pattern"
      values = ["${element(var.alb_listener_path_patterns, count.index)}"]
    },
  ]
}

resource "aws_alb_listener_rule" "listener_rule_no_host" {
  count        = "${var.auth_issuer == "" && !var.aws_alb_use_host_header ? length(var.alb_listener_path_patterns) : 0}"
  listener_arn = "${var.aws_alb_listener_arn}"
  priority     = "${var.listener_rule_priority + count.index}"

  action {
    type             = "forward"
    target_group_arn = "${aws_alb_target_group.target_group.arn}"
  }

  condition = [
    {
      field  = "path-pattern"
      values = ["${element(var.alb_listener_path_patterns, count.index)}"]
    }
  ]
}

resource "aws_alb_listener_rule" "listener_rule_auth" {
  count        = "${var.auth_issuer != "" ? length(var.alb_listener_path_patterns) : 0}"
  listener_arn = "${var.aws_alb_listener_arn}"
  priority     = "${var.listener_rule_priority + count.index}"

  action {
    type = "authenticate-oidc"

    authenticate_oidc {
      authorization_endpoint     = "${var.auth_endpoint}"
      client_id                  = "${var.auth_client_id}"
      client_secret              = "${var.auth_client_secret}"
      issuer                     = "${var.auth_issuer}"
      token_endpoint             = "${var.auth_token_endpoint}"
      user_info_endpoint         = "${var.auth_user_info_endpoint}"
      on_unauthenticated_request = "${var.auth_unauth_action}"
      scope                      = "${var.auth_scope}"
    }
  }

  action {
    type             = "forward"
    target_group_arn = "${aws_alb_target_group.target_group.arn}"
  }

  condition = [
    {
      field  = "host-header"
      values = ["${coalescelist(aws_route53_record.dns_record.*.name, list(var.dns_record_name))}"]
    },
    {
      field  = "path-pattern"
      values = ["${element(var.alb_listener_path_patterns, count.index)}"]
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
  value = "https://${element(coalescelist(aws_route53_record.dns_record.*.name, list(var.dns_record_name)), 0)}"
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
