resource "aws_imagebuilder_image_pipeline" "container_image_pipeline" {
  description                      = "Container image pipeline for ${local.name_prefix}"
  container_recipe_arn             = var.container_recipe_arn
  infrastructure_configuration_arn = var.infrastructure_configuration_arn
  name                             = "${local.name_prefix}-image_pipeline"

  lifecycle {
    replace_triggered_by = [
      aws_imagebuilder_container_recipe.example
    ]
  }

  tags = local.tags
}

resource "aws_ecr_repository" "ecr_repository" {
  name                 = "${local.name_prefix}-ecr-repository"
  image_tag_mutability = "IMMUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "KMS"
    kms_key         = var.ecr_kms_key_id
  }

  tags = local.tags
}

resource "aws_imagebuilder_container_recipe" "container_recipe" {
  name           = "${local.name_prefix}-container-recipe"
  version        = "1.0.0"
  container_type = "DOCKER"
  parent_image   = var.container_image
  tags           = local.tags

  target_repository {
    repository_name = aws_ecr_repository.ecr_repository.name
    service         = "ECR"
  }

  component {
    component_arn = aws_imagebuilder_component.base_component.arn

    parameter {
      name  = "Parameter1"
      value = "Value1"
    }

    parameter {
      name  = "Parameter2"
      value = "Value2"
    }
  }

  dockerfile_template_data = <<EOF
FROM {{{ imagebuilder:parentImage }}}
{{{ imagebuilder:environments }}}
{{{ imagebuilder:components }}}
EOF
}

resource "aws_imagebuilder_component" "base_component" {
  name       = "${local.name_prefix}-base_component"
  platform   = "Linux"
  version    = local.image_builder_base_component_version
  kms_key_id = var.imagebuilder_component_kms_key_id
  # Modify this to be parameterized
  data = yamlencode({
    phases = [{
      name = "build"
      steps = [{
        action = "ExecuteBash"
        inputs = {
          commands = ["echo 'hello world'"]
        }
        name      = "example"
        onFailure = "Continue"
      }]
    }]
    schemaVersion = 1.0
  })
}
