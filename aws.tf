terraform {
  backend "s3" {
    region = "eu-west-1"
  }
}

provider "aws" {
  version = ">= 1.9.0"
  allowed_account_ids = ["${var.aws_account_id}"]
  assume_role {
    role_arn  = "${var.aws_assume_role_arn}"
  }
  region     = "eu-west-1"
}

data "aws_caller_identity" "current" {}

data "aws_ecs_cluster" "ecs-cluster" {
  cluster_name = "${var.ecs_cluster_name}"
}

data "aws_lb" "eq" {
  arn = "${var.aws_alb_arn}"
}

data "aws_route53_zone" "dns_zone" {
  name = "${var.dns_zone_name}"
}
