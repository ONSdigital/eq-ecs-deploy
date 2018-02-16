variable "env" {
  description = "The environment name, used to identify your environment"
}

variable "aws_secret_key" {
  description = "Amazon Web Service Secret Key"
}

variable "aws_access_key" {
  description = "Amazon Web Service Access Key"
}

variable "ecs_cluster_name" {
  description = "The name of the ECS cluster"
}

variable "aws_alb_listener_arn" {
  description = "The ARN of the ALB"
}

variable "service_name" {
  description = "The service name used in the URL"
}

# DNS
variable "dns_zone_name" {
  description = "Amazon Route53 DNS zone name"
  default     = "eq.ons.digital."
}

# ECS
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

variable "container_environment_variables" {
  type = "string"
  description = "The Environment Variables to pass to the container"
  default = ""
}

variable "applciation_min_tasks" {
  description = "The minimum number of tasks to run"
  default     = "2"
}

variable "healthcheck_path" {
  description = "The path for the Healthcheck path. Should report 200 status"
  default     = "/"
}

variable "task_iam_policy_json" {
  description = "The IAM policy to be used by the container task"
  default     = ""
}