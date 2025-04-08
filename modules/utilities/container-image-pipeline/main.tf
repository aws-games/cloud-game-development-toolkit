data "aws_region" "current" {}

resource "aws_imagebuilder_image_pipeline" "container_image_pipeline" {
  description                      = "Container image pipeline for ${local.name_prefix}"
  container_recipe_arn             = aws_imagebuilder_container_recipe.container_recipe.arn
  infrastructure_configuration_arn = aws_imagebuilder_infrastructure_configuration.infrastructure_configuration.arn
  name                             = "${local.name_prefix}-image-pipeline"

  lifecycle {
    replace_triggered_by = [
      aws_imagebuilder_container_recipe.container_recipe
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
  version        = var.container_recipe_version
  container_type = "DOCKER"
  parent_image   = var.parent_container_image
  tags           = local.tags

  target_repository {
    repository_name = aws_ecr_repository.ecr_repository.name
    service         = "ECR"
  }

  component {
    component_arn = aws_imagebuilder_component.base_component.arn
  }

  dockerfile_template_data = <<EOF
FROM {{{ imagebuilder:parentImage }}}
{{{ imagebuilder:environments }}}
{{{ imagebuilder:components }}}
EOF
}

resource "aws_imagebuilder_component" "base_component" {
  name       = "${local.name_prefix}-base-component"
  platform   = "Linux"
  version    = var.image_builder_base_component_version
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

resource "aws_imagebuilder_infrastructure_configuration" "infrastructure_configuration" {
  name                          = "${local.name_prefix}-infrastructure-configuration"
  description                   = "Infrastructure configuration for ${local.name_prefix}"
  instance_profile_name         = aws_iam_instance_profile.image_builder_instance_profile.name
  instance_types                = var.imagebuilder_instance_types
  terminate_instance_on_failure = true
  security_group_ids            = var.security_group_ids != null ? var.security_group_ids : null
  subnet_id                     = var.subnet_id != null ? var.subnet_id : null
  resource_tags                 = local.tags
  tags                          = local.tags
}

resource "aws_imagebuilder_distribution_configuration" "distribution_configuration" {
  #checkov:skip=CKV_AWS_199: KMS Encryption disabled by default. Service default encryption is used.
  name        = "${local.name_prefix}-distribution-configuration"
  description = "Distribution configuration for ${local.name_prefix}"

  distribution {
    region = data.aws_region.current.name
    container_distribution_configuration {
      description = "Container distribution configuration for ${local.name_prefix}"
      target_repository {
        service         = "ECR"
        repository_name = aws_ecr_repository.ecr_repository.name
      }
    }
  }
  tags = local.tags
}
