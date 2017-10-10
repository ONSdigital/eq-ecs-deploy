provider "aws" {
  access_key = "${var.aws_access_key}"
  secret_key = "${var.aws_secret_key}"
  region     = "eu-west-1"
}

data "aws_caller_identity" "current" {}

data "aws_ecs_cluster" "ecs-cluster" {
  cluster_name = "${var.ecs_cluster_name}"
}

data "aws_alb_listener" "eq" {
  arn = "${var.aws_alb_listener_arn}"
}

data "aws_alb" "eq" {
  arn = "${data.aws_alb_listener.eq.load_balancer_arn}"
}

data "aws_route53_zone" "dns_zone" {
  name = "${var.dns_zone_name}"
}
