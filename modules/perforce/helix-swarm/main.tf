# If cluster name is not provided create a new cluster
resource "aws_ecs_cluster" "helix_swarm_cluster" {
  count = var.cluster_name != null ? 0 : 1
  name  = "${local.name_prefix}-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = local.tags
}

resource "aws_ecs_cluster_capacity_providers" "helix_swarm_cluster_fargate_providers" {
  count        = var.cluster_name != null ? 0 : 1
  cluster_name = aws_ecs_cluster.helix_swarm_cluster[0].name

  capacity_providers = ["FARGATE"]

  default_capacity_provider_strategy {
    base              = 1
    weight            = 100
    capacity_provider = "FARGATE"
  }
}

resource "aws_cloudwatch_log_group" "helix_swarm_service_log_group" {
  #checkov:skip=CKV_AWS_158: KMS Encryption disabled by default
  name              = "${local.name_prefix}-log-group"
  retention_in_days = var.helix_swarm_cloudwatch_log_retention_in_days
  tags              = local.tags
}

resource "aws_cloudwatch_log_group" "helix_swarm_redis_service_log_group" {
  #checkov:skip=CKV_AWS_158: KMS Encryption disabled by default
  name              = "${local.name_prefix}-redis-log-group"
  retention_in_days = var.helix_swarm_cloudwatch_log_retention_in_days
  tags              = local.tags
}

# Define swarm task definition
resource "aws_ecs_task_definition" "helix_swarm_task_definition" {
  family                   = var.name
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.helix_swarm_container_cpu
  memory                   = var.helix_swarm_container_memory

  volume {
    name = local.helix_swarm_data_volume_name
  }

  container_definitions = jsonencode(
    [
      {
        name      = var.helix_swarm_container_name,
        image     = local.helix_swarm_image,
        cpu       = var.helix_swarm_container_cpu,
        memory    = var.helix_swarm_container_memory,
        essential = true,
        portMappings = [
          {
            containerPort = var.helix_swarm_container_port,
            hostPort      = var.helix_swarm_container_port
            protocol      = "tcp"
          }
        ]
        healthCheck = {
          command     = ["CMD-SHELL", "curl -f http://localhost:${var.helix_swarm_container_port}/login || exit 1"]
          startPeriod = 30
        }
        logConfiguration = {
          logDriver = "awslogs"
          options = {
            awslogs-group         = aws_cloudwatch_log_group.helix_swarm_service_log_group.name
            awslogs-region        = data.aws_region.current.name
            awslogs-stream-prefix = "helix-swarm"
          }
        }
        secrets = [
          {
            name      = "P4D_SUPER",
            valueFrom = var.p4d_super_user_arn
          },
          {
            name      = "P4D_SUPER_PASSWD",
            valueFrom = var.p4d_super_user_password_arn
          },
          {
            name      = "SWARM_USER"
            valueFrom = var.p4d_swarm_user_arn
          },
          {
            name      = "SWARM_PASSWD"
            valueFrom = var.p4d_swarm_password_arn
          }
        ]
        environment = [
          {
            name  = "P4D_PORT",
            value = var.p4d_port
          },
          {
            name  = "SWARM_HOST"
            value = var.fully_qualified_domain_name
          },
          {
            name  = "SWARM_REDIS"
            value = var.existing_redis_connection != null ? var.existing_redis_connection.host : aws_elasticache_cluster.swarm[0].cache_nodes[0].address
          },
          {
            name  = "SWARM_REDIS_PORT"
            value = var.existing_redis_connection != null ? tostring(var.existing_redis_connection.port) : tostring(aws_elasticache_cluster.swarm[0].cache_nodes[0].port)
          },
        ],
        readonlyRootFilesystem = false
        mountPoints = [
          {
            sourceVolume  = local.helix_swarm_data_volume_name
            containerPath = local.helix_swarm_data_path
            readOnly      = false
          }
        ],
      },
      {
        name      = local.helix_swarm_data_volume_name
        image     = "bash"
        essential = false
        environment = [
          {
            name  = "HELIX_SWARM_DATA_PATH",
            value = local.helix_swarm_data_path
          },
          {
            name  = "HELIX_SWARM_DATA_CACHE_PATH",
            value = "${local.helix_swarm_data_path}/cache"
          },
          {
            name  = "HELIX_SWARM_CONFIG_PHP_PATH",
            value = "${local.helix_swarm_data_path}/${aws_s3_object.helix_swarm_custom_config_php.key}"
          },
          {
            name  = "HELIX_SWARM_CONFIG_S3_BUCKET",
            value = aws_s3_bucket.helix_swarm_config_bucket.id
          },
          {
            name  = "HELIX_SWARM_CONFIG_S3_OBJECT",
            value = aws_s3_object.helix_swarm_custom_config_php.key
          },
          {
            name  = "HELIX_SWARM_CONFIG_S3_OBJECT_S3_URI",
            value = "s3://${aws_s3_bucket.helix_swarm_config_bucket.id}/${aws_s3_object.helix_swarm_custom_config_php.key}"
          },

        ],
        # TODO - Modify this to fetch the object from the S3 bucket using env vars $HELIX_SWARM_CONFIG_S3_BUCKET and $HELIX_SWARM_CONFIG_S3_OBJECT

        # First will need to install the AWS CLI and then run the following commands:
        #1. Install the AWS CLI
        # curl "https://awscli.amazonaws.com/awscli-exe-linux-aarch64.zip" -o "awscliv2.zip"
        # unzip awscliv2.zip
        # sudo ./aws/install

        # 2. Copy file from S3 to Helix Swarm Data Directory
        # Ex. With Terraform Variables
        # aws s3 cp s3://${aws_s3_bucket.helix_swarm_config_bucket.id}/config.php ${local.helix_swarm_data_path}/config.php
        # Ex. With Env Vars (created from Terraform Variables)
        # aws s3 cp $HELIX_SWARM_CONFIG_S3_OBJECT_S3_URI $HELIX_SWARM_CONFIG_PHP_PATH

        # 3. Delete the cache to reload swarm using the new config
        # Ex. With Terraform Variables
        # rm -rf ${local.helix_swarm_data_path}/cache
        # Ex. With Env Vars (created from Terraform Variables)
        # rm -rf $HELIX_SWARM_DATA_CACHE_PATH

        # 4. Configure this task definition to be dependent on the S3 Object so the new versions of the task definition is created whenever new versions of the config.php file are created in S3


        # entryPoint = [
        #   "/bin/sh",
        #   "-c",
        #   "if [ ! -f ${local.helix_swarm_data_path}/config.php ]; then aws s3 cp s3://${aws_s3_bucket.helix_swarm_config_bucket.id}/${aws_s3_object.helix_swarm_custom_config_php.key} ${local.helix_swarm_data_path}/config.php; fi",
        # ]
        // Only run this command if enable_sso is set
        command = concat([], var.enable_sso ? [
          "sh",
          "-c",
          "echo \"/p4/a\\\t'sso' => 'enabled',\" > ${local.helix_swarm_data_path}/sso.sed && sed -i -f ${local.helix_swarm_data_path}/sso.sed ${local.helix_swarm_data_path}/config.php && rm -rf ${local.helix_swarm_data_path}/cache",
        ] : []),

        # Only run this command if var.use_custom_config_php is 'true' and custom config.php file is provided. Command will remove the cache so Swarm will reload with the new config.php file.

        # command = concat([], var.use_custom_config_php ? "rm -rf ${local.helix_swarm_data_path}/cache" : []),
        # command =

        readonly_root_filesystem = false

        logConfiguration = {
          logDriver = "awslogs"
          options = {
            awslogs-group         = aws_cloudwatch_log_group.helix_swarm_service_log_group.name
            awslogs-region        = data.aws_region.current.name
            awslogs-stream-prefix = local.helix_swarm_data_volume_name
          }
        }
        mountPoints = [
          {
            sourceVolume  = local.helix_swarm_data_volume_name
            containerPath = local.helix_swarm_data_path
          }
        ],
        dependsOn = [
          {
            containerName = var.helix_swarm_container_name
            condition     = "HEALTHY"
          },
          # S3 object/Config.php file dependency
          # We should avoid having dependency on data source for s3 object, ex:
          # `data.aws_s3_object.config_php.checksum_sha256`or `data.aws_s3_object.config_php.etag`. This is because when using a data source, a value is known AFTER apply. This will cause an issue where the task definition will be re-created on every run of `terraform apply` even if there have been no changes to the config.php file.

          # Instead, recommend dependency of the `aws_s3_object` resource, specifically something like `aws_s3_object.helix_swarm_config_php.checksum_sha256` OR `aws_s3_object.helix_swarm_config_php.etag`. This is dependent on the `local_file` resource that is generating the file to be uploaded, so Terraform would have local context on if this has changed or not when determining if it needs to update the S3 Object

          # Alternatively, could probably also directly reference the `local_file` checksum, since that will be known DURING apply since Terraform will have context of this without having to fetch data from a remote API

        ]
      }
    ]
  )

  task_role_arn      = var.custom_helix_swarm_role != null ? var.custom_helix_swarm_role : aws_iam_role.helix_swarm_default_role[0].arn
  execution_role_arn = aws_iam_role.helix_swarm_task_execution_role.arn

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64"
  }

  tags = local.tags
}

# Define swarm service
resource "aws_ecs_service" "helix_swarm_service" {
  name = "${local.name_prefix}-service"

  cluster                = var.cluster_name != null ? data.aws_ecs_cluster.helix_swarm_cluster[0].arn : aws_ecs_cluster.helix_swarm_cluster[0].arn
  task_definition        = aws_ecs_task_definition.helix_swarm_task_definition.arn
  launch_type            = "FARGATE"
  desired_count          = var.helix_swarm_desired_container_count
  force_new_deployment   = var.debug
  enable_execute_command = var.debug

  load_balancer {
    target_group_arn = aws_lb_target_group.helix_swarm_alb_target_group.arn
    container_name   = var.helix_swarm_container_name
    container_port   = var.helix_swarm_container_port
  }

  network_configuration {
    subnets         = var.helix_swarm_service_subnets
    security_groups = [aws_security_group.helix_swarm_service_sg.id]
  }

  tags = local.tags

  depends_on = [aws_elasticache_cluster.swarm]
}

resource "local_file" "custom_config_php" {
  filename = "${path.root}/Helix-Swarm-Config/config.php"
  content  = <<-EOF
<?php
/* WARNING: This file was auto-generated by the Cloud Game Development Toolkit Perforce Helix-Swarm Terraform Module.

The contents of this file are cached by Swarm. Subsequent changes made to this file will not be picked up by Swarm until the cached versions are removed. Programmatic changes made using the Terraform Module handles this on your behalf.

If making changes manually (external to the Terraform Module), see the Helix Swarm docs on config cache file deletion for more information on how to do this manually: https://help.perforce.com/helix-core/helix-swarm/swarm/current/Content/Swarm/swarm-apidoc_endpoint_config_cache.html
 */
return array(
    'environment' => array(
        'hostname' => 'swarm.perforce.${var.config_php_hostname}',
    ),
    'p4' => array(
            'port'       => '${var.config_php_p4.port}',
            'user'       => '${var.config_php_p4.user}',
            'password'   => '${var.config_php_p4.password}',
            'sso'        => '${var.config_php_p4.sso}', // ['disabled'|'optional'|'enabled'] default value is 'disabled'
        ),
    'mail' => array(
            // 'recipients' => array('${var.config_php_mail.recipient}'),
            'notify_self'   => false,
            'transport' => array(
                'name' => '${var.config_php_mail.name}' // name of the SMTP host
                'host' => '${var.config_php_mail.host}',          // host/IP of SMTP host
                'port' => ${var.config_php_mail.port},                  // SMTP host listening port
                'connection_class'  => '${var.config_php_mail.connection_class}', // 'smtp', 'plain', 'login', 'crammd5'
                'connection_config' => array(   // include when auth required to send
                'username'  => '${var.config_php_mail.username}',      // user on SMTP host
                'password'  => '${var.config_php_mail.password}',      // password for user on SMTP host
                'ssl'       => '${var.config_php_mail.connection_security}',       // empty, 'tls', or 'ssl'
            ),
        ),
    'log' => [
        'priority' => 7,
    ],
    'redis' => [
        'options' => [
            'server' => [
                'host' => '${var.config_php_redis.host}',
                'port' => ${var.config_php_redis.port},
            ],
        ],
    ],
);
  EOF
}

# - Random Strings to prevent naming conflicts -
resource "random_string" "helix_swarm_config_bucket" {
  length  = 4
  special = false
  upper   = false
}

# Create S3 bucket to store Helix Swarm Config File
resource "aws_s3_bucket" "helix_swarm_config_bucket" {
  bucket        = "${var.cluster_name}-helix-swarm-config-${random_string.helix_swarm_config_bucket.result}"
  force_destroy = true
  tags = {
    ECS_Cluster_Name = var.cluster_name
  }
}

# Enable S3 Bucket Versioning
resource "aws_s3_bucket_versioning" "helix_swarm_config_bucket" {
  bucket = aws_s3_bucket.helix_swarm_config_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Restrict S3:PutObject unless the file is the custom config.php file
data "aws_iam_policy_document" "helix_swarm_config_bucket" {
  statement {
    principals {
      type = "AWS"
      identifiers = [
        data.aws_caller_identity.current.account_id,
      ]
    }
    effect = "Allow"
    actions = [
      "s3:PutObject",
    ]
    # Allows S3:PutObject but only if the file being uploaded is the custom config.php file
    resources = [
      "${aws_s3_bucket.helix_swarm_config_bucket.arn}/config.php",
    ]
  }
  statement {
    principals {
      type = "AWS"
      identifiers = [
        data.aws_caller_identity.current.account_id,
      ]
    }
    effect = "Deny"
    actions = [
      "s3:PutObject",
    ]
    # Allows S3:PutObject but only if the file being uploaded is the custom config.php file
    not_resources = [
      "${aws_s3_bucket.helix_swarm_config_bucket.arn}/config.php",
    ]
  }
}

resource "aws_s3_bucket_policy" "helix_swarm_config_bucket" {
  bucket = aws_s3_bucket.helix_swarm_config_bucket.id
  policy = data.aws_iam_policy_document.helix_swarm_config_bucket.json
}



# # - Sleep to avoid eventual consistency  -
# resource "time_sleep" "wait_20_seconds" {
#   depends_on = [
#     aws_s3_bucket.helix_swarm_config_bucket,
#   null_resource.put_s3_object]

#   create_duration = "20s"
# }


# resource "aws_s3_object" "unreal_horde_agent_playbook" {
#   count  = length(var.agents) > 0 ? 1 : 0
#   bucket = aws_s3_bucket.ansible_playbooks[0].id
#   key    = "/agent/horde-agent.ansible.yml"
#   source = "${path.module}/config/agent/horde-agent.ansible.yml"
#   etag   = filemd5("${path.module}/config/agent/horde-agent.ansible.yml")
# }

# Push custom config.php file to S3 bucket
resource "aws_s3_object" "helix_swarm_custom_config_php" {
  bucket = aws_s3_bucket.helix_swarm_config_bucket.id
  key    = "config.php"
  source = local_file.custom_config_php.filename
  # md5() function must be used instead of filemd5() function because all Terraform functions run during the initial configuration processing, not during graph walk. Since using the local_file resource to create the file, it would not yet exist when the function runs. Instead, we can use the .content attribute available from the local_file resource itself.
  etag          = md5(local_file.custom_config_php.content)
  force_destroy = true

  # depends_on = [local_file.custom_config_php]
}

# # Temporary workaround until this GitHub issue on aws_s3_object is resolved: https://github.com/hashicorp/terraform-provider-aws/issues/12652
# resource "null_resource" "put_s3_object" {
#   # Will only trigger this resource to re-run if changes are made to the custom config.php file via the local_file resource
#   triggers = {
#     src_hash = local_file.custom_config_php.content_sha256
#   }

#   # Put custom config.php file in Helix Swarm Config S3 Bucket
#   provisioner "local-exec" {
#     command = "aws s3 cp config.php s3://${aws_s3_bucket.helix_swarm_config_bucket.id}/config.php"

#   }

#   # Only attempt to put the file when the S3 Bucket (and related resources) are created
#   depends_on = [
#     aws_s3_bucket.helix_swarm_config_bucket,
#     aws_s3_bucket_notification.helix_swarm_config_bucket,
#     aws_s3_bucket_policy.helix_swarm_config_bucket,
#     aws_s3_bucket_versioning.helix_swarm_config_bucket
#   ]
# }

# resource "null_resource" "update_helix_swarm_config" {
#   # Will only trigger this resource to re-run if changes are made to the custom config.php file via the local_file resource
#   triggers = {
#     src_hash = local_file.custom_config_php.content_sha256
#   }

#   # Fetch
#   provisioner "local-exec" {
#     command = <<-EOF
#       aws ecs execute-command --region ${data.aws_region.current} --cluster ${var.cluster_name} --task $TASK_ID --command "aws s3 cp s3://${aws_s3_bucket.helix_swarm_config_bucket.id}/config.php SWARM_ROOT/data/config.php"
#     EOF

#   }

#   # Only attempt to put the file when the S3 Bucket (and related resources) are created
#   depends_on = [
#     aws_s3_bucket.helix_swarm_config_bucket,
#     aws_s3_bucket_notification.helix_swarm_config_bucket,
#     aws_s3_bucket_policy.helix_swarm_config_bucket,
#     aws_s3_bucket_versioning.helix_swarm_config_bucket
#   ]
# }



