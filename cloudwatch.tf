resource "aws_cloudwatch_metric_alarm" "service_high_cpu" {
  alarm_name          = "${var.env}-${var.service_name}-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = "60"
  statistic           = "Average"
  threshold           = "${var.high_cpu_threshold}"

  dimensions {
    ClusterName = "${data.aws_ecs_cluster.ecs-cluster.cluster_name}"
    ServiceName = "${aws_ecs_service.service.name}"
  }

  alarm_description = "This metric monitors ${var.service_name} ECS Service cpu utilization"
  alarm_actions     = ["${aws_appautoscaling_policy.service_scale.arn}"]
}

resource "aws_cloudwatch_metric_alarm" "service_low_cpu" {
  alarm_name          = "${var.env}-${var.service_name}-low-cpu"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "5"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = "60"
  statistic           = "Average"
  threshold           = "${var.low_cpu_threshold}"

  dimensions {
    ClusterName = "${data.aws_ecs_cluster.ecs-cluster.cluster_name}"
    ServiceName = "${aws_ecs_service.service.name}"
  }

  alarm_description = "This metric monitors ${var.service_name} ECS Service cpu utilization"
  alarm_actions     = ["${aws_appautoscaling_policy.service_scale.arn}"]
}

resource "aws_cloudwatch_metric_alarm" "5xx_errors" {
  alarm_name          = "${var.env}-${var.service_name}-5xx-errors"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "1"
  metric_name         = "HTTPCode_Target_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = "60"
  statistic           = "Sum"
  threshold           = "1"
  alarm_description   = "There have been at least 1 5xx errors in the past 60 seconds"
  alarm_actions       = ["${var.slack_alert_sns_arn}"]
  treat_missing_data  = "notBreaching"

  dimensions {
    TargetGroup  = "${aws_alb_target_group.target_group.arn_suffix}"
    LoadBalancer = "${data.aws_lb.eq.arn_suffix}"
  }
}

resource "aws_cloudwatch_metric_alarm" "4xx_errors" {
  alarm_name          = "${var.env}-${var.service_name}-4xx-errors"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "2"
  metric_name         = "HTTPCode_Target_4XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = "60"
  statistic           = "Sum"
  threshold           = "100"
  alarm_description   = "There have been at least 100 4xx errors in the past 120 seconds"
  treat_missing_data  = "notBreaching"

  dimensions {
    TargetGroup  = "${aws_alb_target_group.target_group.arn_suffix}"
    LoadBalancer = "${data.aws_lb.eq.arn_suffix}"
  }
}
