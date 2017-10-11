# eq-ecs-deploy

This repository contains a Terraform module that provides a lot of the boilerplate configuration required to deploy a container to an ECS cluster.

Below is an example how to to use this module alongside a container definitions json file.

```
data "template_file" "schema-validator" {
  template = "${file("${path.module}/task-definitions/schema-validator.json")}"

  vars {
    CONTAINER_NAME     = "${var.application_name}"
    LOG_GROUP          = "${var.env}-${var.application_name}"
    CONTAINER_REGISTRY = "${var.docker_registry}"
    CONTAINER_TAG      = "${var.container_tag}"
  }
}

module "ecs-service" {
  source                = "github.com/ONSdigital/eq-ecs-deploy?ref=create-common-ecs-deploy"
  env                   = "${var.env}"
  aws_secret_key        = "${var.aws_secret_key}"
  aws_access_key        = "${var.aws_access_key}"
  ecs_cluster_name      = "${var.ecs_cluster_name}"
  aws_alb_listener_arn  = "${var.aws_alb_listener_arn}"
  dns_zone_name         = "${var.dns_zone_name}"
  application_name      = "${var.application_name}"
  container_port        = "5000"
  container_definitions = "${data.template_file.schema-validator.rendered}"
}
```