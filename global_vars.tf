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

# DNS
variable "dns_zone_name" {
  description = "Amazon Route53 DNS zone name"
  default     = "eq.ons.digital."
}

# ECS
variable "application_name" {
  description = "The name for the application being deployed"
}

variable "container_port" {
  description = "The port that the container exposes"
}

variable "applciation_min_tasks" {
  description = "The minimum number of tasks to run"
  default     = "1"
}

variable "healthcheck_path" {
  description = "The path for the Healthcheck path. Should report 200 status"
  default     = "/"
}

variable "container_definitions" {
  description = "The rendered container definitions json. Name must match `application_name`"
}
