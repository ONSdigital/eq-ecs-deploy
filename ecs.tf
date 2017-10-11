resource "aws_alb_target_group" "target_group" {
  name     = "${var.env}-${var.application_name}"
  port     = 80
  protocol = "HTTP"
  vpc_id   = "${data.aws_alb.eq.vpc_id}"

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
  listener_arn = "${var.aws_alb_listener_arn}"
  priority     = 20

  action {
    type             = "forward"
    target_group_arn = "${aws_alb_target_group.target_group.arn}"
  }

  condition {
    field  = "host-header"
    values = ["${aws_route53_record.dns_record.name}"]
  }
}

resource "aws_route53_record" "dns_record" {
  zone_id = "${data.aws_route53_zone.dns_zone.id}"
  name    = "${var.env}-${var.application_name}.${data.aws_route53_zone.dns_zone.name}"
  type    = "CNAME"
  ttl     = "60"
  records = ["${data.aws_alb.eq.dns_name}"]
}

resource "aws_ecs_task_definition" "task_definition" {
  family                = "${var.env}-${var.application_name}"
  container_definitions = "${var.container_definitions}"
}

resource "aws_ecs_service" "service" {
  depends_on = [
    "aws_alb_target_group.target_group",
    "aws_alb_listener_rule.listener_rule",
  ]

  name            = "${var.env}-${var.application_name}"
  cluster         = "${data.aws_ecs_cluster.ecs-cluster.id}"
  task_definition = "${aws_ecs_task_definition.task_definition.family}"
  desired_count   = "${var.applciation_min_tasks}"
  iam_role        = "${aws_iam_role.service_iam_role.arn}"

  placement_strategy {
    type  = "spread"
    field = "host"
  }

  load_balancer {
    target_group_arn = "${aws_alb_target_group.target_group.arn}"
    container_name   = "${var.application_name}"
    container_port   = "${var.container_port}"
  }

  lifecycle {
    ignore_changes = ["placement_strategy"]
  }
}

resource "aws_iam_role" "service_iam_role" {
  name = "${var.env}_iam_for_${var.application_name}"

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
  name   = "${var.env}_iam_for_survey_register"
  role   = "${aws_iam_role.service_iam_role.id}"
  policy = "${data.aws_iam_policy_document.policy_document.json}"
}

resource "aws_cloudwatch_log_group" "log_group" {
  name = "${var.env}-${var.application_name}"

  tags {
    Environment = "${var.env}"
  }
}

output "service_address" {
  value = "https://${aws_route53_record.dns_record.fqdn}"
}
