variable "env" {
  description = "The environment name, used to identify your environment"
}

variable "aws_account_id" {
  description = "Amazon Web Service Account ID"
}

variable "aws_assume_role_arn" {
  description = "IAM Role to assume on AWS"
}

variable "vpc_id" {
  description = "The EQ VPC ID"
}

variable "ecs_cluster_name" {
  description = "The name of the ECS cluster"
}

variable "aws_alb_arn" {
  description = "The ARN of the ALB"
}

variable "aws_alb_listener_arn" {
  description = "The ARN of the ALB"
}

variable "alb_listener_path_pattern" {
  description = "The path pattern to match to route to this service"
  default     = "/*"
}

variable "service_name" {
  description = "The service name used in the URL"
}

variable "slack_alert_sns_arn" {
  description = "The ARN of sns topic for slack alerts"
}

variable "ecs_subnet_ids" {
  description = "The Subnet Ids where ecs runs"
  type        = "list"
  default     = []
}

variable "ecs_alb_security_group" {
  description = "The security group that allows access from the LB"
  type        = "list"
  default     = []
}

# DNS
variable "dns_zone_name" {
  description = "Amazon Route53 DNS zone name"
  default     = "eq.ons.digital."
}

variable "dns_record_name" {
  description = "The DNS recored name of an existing Route53 Record to use"
  default     = ""
}

# ECS
variable "launch_type" {
  description = "Where to launch the container. Either FARGATE or EC2"
  default     = "EC2"
}

variable "cpu_units" {
  description = "The number of cpu units used by the task"
  default     = "1024"
}

variable "memory_units" {
  description = "The amount (in MiB) of memory used by the task"
  default     = "2048"
}

variable "listener_rule_priority" {
  description = "The priority to set on the ALB listener rule"
}

variable "docker_registry" {
  description = "The docker repository for the image"
  default     = "onsdigital"
}

variable "container_name" {
  description = "The name of the image to deploy"
}

variable "container_tag" {
  description = "The tag for the image to deploy"
  default     = "latest"
}

variable "container_port" {
  description = "The port that the container exposes"
}

variable "container_memory_reservation" {
  description = "How much memory should be reserved for this container"
  default     = 128
}

variable "container_environment_variables" {
  type        = "string"
  description = "The Environment Variables to pass to the container"
  default     = ""
}

variable "application_min_tasks" {
  description = "The minimum number of tasks to run"
  default     = "2"
}

variable "application_max_tasks" {
  description = "The maximum number of tasks to run"
  default     = "100"
}

variable "healthcheck_path" {
  description = "The path for the Healthcheck path. Should report 200 status"
  default     = "/"
}

variable "task_has_iam_policy" {
  description = "Does this task have an IAM policy attached"
  default     = false
}

variable "task_iam_policy_json" {
  description = "The IAM policy to be used by the container task"
  default     = ""
}

# Cloudwatch
variable "high_cpu_threshold" {
  description = "The Average CPU usage at which to trigger the high CPU alarm"
  default     = "40"
}

variable "low_cpu_threshold" {
  description = "The Average CPU usage at which to trigger the low CPU alarm"
  default     = "20"
}

variable "healthcheck_grace_period_seconds" {
  description = "Number of seconds to wait before first health check."
  default     = 5
}
