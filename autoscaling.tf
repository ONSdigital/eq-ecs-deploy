resource "aws_appautoscaling_target" "ecs_service_target" {
  min_capacity       = "${var.application_min_tasks}"
  max_capacity       = "${var.application_max_tasks}"
  resource_id        = "service/${data.aws_ecs_cluster.ecs-cluster.cluster_name}/${var.env}-${var.service_name}"
  role_arn           = "${data.aws_iam_role.aws_ecs_auto_scaling.arn}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

data "aws_iam_role" "aws_ecs_auto_scaling" {
  name = "AWSServiceRoleForApplicationAutoScaling_ECSService"
}

resource "aws_appautoscaling_policy" "service_scale" {
  name               = "${var.env}-${var.service_name}-scaling"
  resource_id        = "service/${data.aws_ecs_cluster.ecs-cluster.cluster_name}/${var.env}-${var.service_name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"

  step_scaling_policy_configuration {
    adjustment_type         = "ChangeInCapacity"
    cooldown                = 30
    metric_aggregation_type = "Maximum"

    step_adjustment {
      metric_interval_lower_bound = 0
      metric_interval_upper_bound = 10
      scaling_adjustment          = 1
    }

    step_adjustment {
      metric_interval_lower_bound = 10
      metric_interval_upper_bound = 20
      scaling_adjustment          = 2
    }

    step_adjustment {
      metric_interval_lower_bound = 20
      scaling_adjustment          = 3
    }

    step_adjustment {
      metric_interval_upper_bound = 0
      scaling_adjustment          = -1
    }
  }

  depends_on = [
    "aws_appautoscaling_target.ecs_service_target",
  ]
}
