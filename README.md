# eq-ecs-deploy

This repository contains a Terraform module that provides the ability to deploy a container to an ECS cluster.

Below is an example how to to use this module.

```

module "schema-validator" {
  source                          = "github.com/ONSdigital/eq-ecs-deploy"
  env                             = "${var.env}"
  aws_access_key                  = "${var.aws_access_key}"
  aws_secret_key                  = "${var.aws_secret_key}"
  dns_zone_name                   = "${var.dns_zone_name}"
  ecs_cluster_name                = "${module.eq-ecs.ecs_cluster_name}"
  aws_alb_listener_arn            = "${module.eq-ecs.aws_alb_listener_arn}"
  container_name                  = "eq-schema-validator"
  container_port                  = 5000
  container_tag                   = "migrate-validation-logic"
  container_environment_variables = <<EOF
  {
      "name": "EXAMPLE_VAR",
      "value": "TEST"
  }
  EOF
}
```