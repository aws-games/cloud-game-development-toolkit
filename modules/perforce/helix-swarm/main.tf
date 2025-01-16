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
          }
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
        // Only run this command if enable_sso is set
        # command = concat([], var.enable_sso ? [
        #   "sh",
        #   "-c",
        #   "echo \"/p4/a\\\t'sso' => 'enabled',\" > ${local.helix_swarm_data_path}/sso.sed && sed -i -f ${local.helix_swarm_data_path}/sso.sed ${local.helix_swarm_data_path}/config.php && rm -rf ${local.helix_swarm_data_path}/cache",
        # ] : []),

        # Only run this command if var.use_custom_config_php is 'true' and custom config.php file is provided. Command will remove the cache so Swarm will reload with the new config.php file.
        command = concat([], var.use_custom_config_php ? "rm -rf ${local.helix_swarm_data_path}/cache" : []),

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
          }
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


# TASKS:
# 1. Modify bash script to conditionally remove the cache to use custom config.php file ✅
# 2. Dynamically create the config.php file.
#   a. Create core template of what is expected in the config.php file
#   b. Using variables (object) with conditionals, dynamically modify the default values of the template
# 3. Upload the new config.php file to the Helix Swarm container
# 4. (stretch) Allow users to alternatively supply their own fully complete custom config.php file


# TODO - Create local_file for config.php and inject into Swarm in ECS

resource "local_file" "custom_config_php" {
  count    = var.use_custom_config_php ? 1 : 0
  filename = "${path.root}/Helix-Swarm-Config/config.php"
  content  = <<-EOF
<?php
    return array(
        'activity' => array(
            'ignored_users' => array(
                'p4dtguser',
                'system',
            ),
        ),
        'archives' => array(
            'max_input_size'    => 512 * 1024 * 1024, // 512M (in bytes)
            'archive_timeout'   => 1800,              // 30 minutes
            'compression_level' => 1,                 // 0-9
            'cache_lifetime'    => 60 * 60 * 24,      // 1 day
        ),
        'avatars' => array(
            'http_url'  => 'http://www.gravatar.com/avatar/{hash}?s={size}&d={default}',
            'https_url' => 'https://secure.gravatar.com/avatar/{hash}?s={size}&d={default}',
        ),
        'comments' => array(
             'notification_delay_time'    => 1800, //Default to 30 minutes 1800 seconds
             'threading'     => array(
                 'max_depth' => 4, // default depth 4, to disable comment threading set to 0
             ),
        ),
        'depot_storage' => array(
            'base_path'  => '//depot_name',
        ),
        'diffs' => array(
            'max_diffs'                  => 1500,
        ),
        'environment' => array(
            'mode'         => 'production',
            'hostname'     => 'myswarm.hostname',
            'external_url' => null,
            'base_url'     => null,
            'logout_url'   => null, // defaults to null
            'vendor'       => array(
                'emoji_path' => 'vendor/gemoji/images',
            ),
        ),
        'files' => array(
            'max_size'         => 1048576,
            'download_timeout' => 1800,
            'allow_edits' => true, // default is true
        ),
        'groups' => array(
            'super_only'  => true, // ['true'|'false'] default value is 'false'
        ),
        'http_client_options'   => array(
            'timeout'       => 10, // default value is 10 seconds
            'sslcapath'     => '', // path to the SSL certificate directory
            'sslcert'       => '', // the path to a PEM-encoded SSL certificate
            'sslpassphrase' => '', // the passphrase for the SSL certificate file
            'hosts'         => array(), // optional, per-host overrides. Host as key, array options as values
        ),
        'jira' => array(
            'host'            => '', // URL for your installed Jira web interface (start with https:// or  http://)
            'api_host'        => '', // URL for Jira API access, 'host' is used for Jira API access if 'api_host' is not set
            'user'            => '', // Jira Cloud: the username used to connect to your Atlassian account
                                     // Jira on-premises: the username required for Jira API access
            'password'        => '', // Jira Cloud: a special API token, obtained from https://id.atlassian.com/manage/api-tokens
                                     // Jira on-premises: the password required for Jira API access
            'job_field'       => '', // optional, if P4DTG is replicating Jira issue IDs to a job field, list that field here
            'link_to_jobs'    => false, // set to true to enable Perforce job links in Jira, P4DTG and job_field required
            'delay_job_links' => 60, // delay in seconds, defaults to 60 seconds
            'relationship'    => '', // Jira subsection name links are added to defaults to empty, links added to the "links to" subsection
        ),
        'linkify' => array(
            'word_length_limit' => 2048, // limit on the number of characters which a text to be linkified can have
            'target' => '_self',         // opens the URL in the same tab or a new tab, defaults to '_self'. To open the URL in a new tab, set to '_blank'
            'markdown' => array(
                array(
                    'id'    =>  'jobs',
                    'regex' => '',       // the regular expression used to match the job keyword, default is empty
                    'url'   => '',       // url that matching job numbers are appended to, default is empty
                ),
            ),
        ),
        'log' => array(
            'priority'     => 3, // 7 for max, defaults to 3
            'reference_id' => false // defaults to false
        ),
        'mail' => array(
            // 'recipients' => array('user@my.domain'),
            'notify_self'   => false,
            'transport' => array(
                'name' => '${config_php_mail.name}' // name of the SMTP host
                'host' => '${config_php_mail.host}',          // host/IP of SMTP host
                'port' => ${config_php_mail.port},                  // SMTP host listening port
                'connection_class'  => '${config_php_mail.connection_class}', // 'smtp', 'plain', 'login', 'crammd5'
                'connection_config' => array(   // include when auth required to send
                'username'  => '${config_php_mail.username}',      // user on SMTP host
                'password'  => '${config_php_mail.password}',      // password for user on SMTP host

                // idk what they want for this. Why isn't the name just 'connection_type' and you pick SSL or TLS?
                'ssl'       => 'tls',       // empty, 'tls', or 'ssl'
                'ssl'       => '${config_php_mail.connection_security}',       // empty, 'tls', or 'ssl'
            ),
        ),
        'markdown' => array(
            'markdown' => 'safe', // default is 'safe' 'disabled'|'safe'|'unsafe'
        ),
        'mentions' => array(
            'mode'  => 'global',
            'user_exclude_list'  => array('super', 'swarm-admin'),
            'group_exclude_list' => array('testers', 'writers'), // defaults to empty
        ),
        'menu_helpers' => array(
            'MyMenu01' => array( // A short recognizable name for the menu item
                'id'        => 'custom01',            // A unique id for the menu item. If not included in the array, parent array name is used.
                'enabled'   => true,                  // ['true'|'false'] 'true' makes the menu item visible. 'true' is the default if not included in the array.
                'target'    => '/module/MyMenuItem/', // The URL or custom module route a menu click takes you to.
                                                      // If not included in array, id is used. If id not included, parent array name is used.
                'cssClass'  => 'custom_menu',         // The custom CSS class name added to the menu item, appended to h2.menu- in Swarm CSS
                'title'     => 'MyMenuItem',          // The text that will be shown on the button.
                                                      // If not included in array, id is used. If id not included, parent array name is used.
                'class'     => '',                    // If not included in array or empty, the menu item is added to the main menu.
                                                      // To add the menu item to the project menu for all of the projects, set to '\Projects\Menu\Helper\ProjectContextMenuHelper'
                'priority'  => 155,                   // The position the menu item is displayed at in the menu.
                                                      // If not included in the array, the menu item is placed at the bottom of the menu.
                'roles'     => null,                  // ['null'|'authenticated'|'admin'|'super'] If not included in the array, null is the default
                                                      // Specifies the minimum level of Perforce user that can see the menu item.
                                                      // 'authenticated' = any authorized user, 'null' = unauthenticated users
            ),
        ),
        'notifications' => array(
            'honor_p4_reviews'      => false,
            'opt_in_review_path'    => '//depot/swarm',
            'disable_change_emails' => false,
        ),
        'p4' => array(
            'port'       => '${config_php_p4.port}',
            'user'       => '${config_php_p4.user}',
            'password'   => '${config_php_p4.password}',
            'sso'        => '${config_php_p4.sso}', // ['disabled'|'optional'|'enabled'] default value is 'disabled'
            'proxy_mode' => ${config_php_p4.proxy_mode}, // defaults to true
            'slow_command_logging' => array(
                3,
                10 => array('print', 'shelve', 'submit', 'sync', 'unshelve'),
            ),
            'max_changelist_files' => ${config_php_p4.max_changelist_files},
            'auto_register_url'    => ${config_php_p4.auto_register_url},
        ),
        'projects' => array(
            'mainlines' => array(
                'stable', 'release', // 'main', 'mainline', 'master', and 'trunk' are hardcoded, there is no need to add them to the array
            ),
            'add_admin_only'           => false,
            'add_groups_only'          => array(),
            'edit_name_admin_only'     => false,
            'edit_branches_admin_only' => false,
            'readme_mode'              => 'enabled',
            'fetch'                    => array('maximum' => 0), // defaults to 0 (disabled)
            'allow_view_settings'      => false, // defaults to false
        ),
        'queue'  => array(
            'workers'             => 3,    // defaults to 3
            'worker_lifetime'     => 595,  // defaults to 10 minutes (less 5 seconds)
            'worker_task_timeout' => 1800, // defaults to 30 minutes
            'worker_memory_limit' => '1G', // defaults to 1 gigabyte
        ),
        'redis' => array(
            'options' => array(
                'password' => null, // Defaults to null
                'namespace' => 'Swarm',
                'server' => array(
                    'host' => 'localhost', // Defaults to 'localhost' or enter your Redis server hostname
                    'port' => '7379', // Defaults to '7379' or enter your Redis server port
                ),
            ),
            'items_batch_size' => 100000,
            'check_integrity' => '03:00', // Defaults to '03:00' Use one of the following options:
                                          //'HH:ii' (24 hour format with leading zeros), the time the integrity check starts each day
                                          // positive integer, the time between integrity checks in seconds. '0' = integrity check disabled
            'population_lock_timeout' => 300, // Timeout for initial cache population. Defaults to 300 seconds.
        ),
        'reviews' => array(
            'patterns' => array(
                'octothorpe' => array(     // #review or #review-1234 with surrounding whitespace/eol
                    'regex'  => '/(?P<pre>(?:\s|^)\(?)\#(?P<keyword>review|append|replace)(?:-(?P<id>[0-9]+))?(?P<post>[.,!?:;)]*(?=\s|$))/i',
                    'spec'   => '%pre%#%keyword%-%id%%post%',
                    'insert' => "%description%\n\n#review-%id%",
                    'strip'  => '/^\s*\#(review|append|replace)(-[0-9]+)?(\s+|$)|(\s+|^)\#(review|append|replace)(-[0-9]+)?\s*$/i',
                ),
                'leading-square' => array(     // [review] or [review-1234] at start
                    'regex'  => '/^(?P<pre>\s*)\[(?P<keyword>review|append|replace)(?:-(?P<id>[0-9]+))?\](?P<post>\s*)/i',
                    'spec'  => '%pre%[%keyword%-%id%]%post%',
                ),
                'trailing-square' => array(     // [review] or [review-1234] at end
                    'regex'  => '/(?P<pre>\s*)\[(?P<keyword>review|append|replace)(?:-(?P<id>[0-9]+))?\](?P<post>\s*)?$/i',
                    'spec'   => '%pre%[%keyword%-%id%]%post%',
                ),
            ),
	    'filters' => array(
                'filter-max' => 15,
                'result_sorting' => true,
  	        'date_field' => 'updated', // 'created' displays and sorts by created date, 'updated' displays and sorts by last updated
	    ),
            'cleanup' => array(
                'mode'        => 'user', // auto - follow default, user - present checkbox(with default)
                'default'     => false,  // clean up pending changelists on commit
                'reopenFiles' => false,   // re-open any opened files into the default changelist
            ),
            'statistics' => array(
                'complexity' => array(
                    'calculation' => 'default', // 'default|disabled'
                    'high' => 300,
                    'low' => 30
                ),
            ),
            'allow_author_change'             => true,
            'allow_author_obliterate'         => false,
            'commit_credit_author'            => true,
            'commit_timeout'                  => 1800, // 30 minutes
            'disable_approve_when_tasks_open' => false,
            'disable_commit'                  => true,
            'disable_self_approve'            => false,
            'end_states'                      => array('archived', 'rejected', 'approved:commit'),
            'expand_all_file_limit'           => 10,
            'expand_group_reviewers'          => false,
            'ignored_users'                   => array(),
            'max_secondary_navigation_items'  => 6,  // defaults to 6
            'moderator_approval'              => 'any', // 'any|each'
            'more_context_lines'              => 10, // defaults to 10 lines
            'process_shelf_delete_when'       => array(),
            'sync_descriptions'               => true,
            'unapprove_modified'              => true,
        ),
        'search' => array(
            'maxlocktime'     => 5000, // 5 seconds, in milliseconds
            'p4_search_host'  => '',   // optional URL to Helix Search Tool
        ),
        'security'  => array(
            'disable_system_info'      => false,
            'email_restricted_changes' => false,
            'emulate_ip_protections'   => false,  // defaults to false
            'https_port'               => null,
            'https_strict'             => false,
            'https_strict_redirect'    => true,
            'require_login'            => true,
            'prevent_login'            => array(
                'service_user1',
                'service_user2',
            ),
        ),
        'session'  => array(
            'cookie_lifetime'            => 0, // lifetime in seconds, default value is 0=expire when browser closed
            'remembered_cookie_lifetime' => 60*60*24*30, // lifetime in seconds, default value is 30 days
            'user_login_status_cache'    => 10, // Set in seconds, default value is 10 seconds.
                                                // Set to 0 to disable the cache and make Swarm
                                                // check the user login status for every call to Helix Server.
            'gc_maxlifetime'             => 60*60*24*30, // lifetime in seconds, default value is 30 days
            'gc_divisor'                 => 100, // 100 user requests
        ),
        'short_links' => array(
            'hostname'     => 'myho.st',
            'external_url' => 'https://myho.st:port/sub-folder',
        ),
        'slack' => array(
             'token' => 'TOKEN',
             'project_channels'             => array(
                                                 'myproject' => array('myproject-channel',), //The Swarm project name must be in lower case letters.
                                                                                             //For project 'myproject' the slack notification
                                                                                             //will go into the Slack channel 'myproject-channel'.
             ),
             'summary_file_names'           => false, //Attaches the file to the original notification message sent to a Slack channel.
             'bypass_restricted_changelist' => false, //Allows Swarm to post notification messages to a Slack channel when a change is committed
                                                      //or a review is created for a restricted changelist, default value is false.
             'summary_file_limit'           => 10, //Limits the number of files shown in the original notification message sent to a Slack channel, default value is 10.
             'user' => array(
                  'enabled'                 => true, //Forces the Swarm app to use the custom username, overrides the Swarm app details.
                  'name'                    => 'Helix Swarm', //This is the username shown in the Slack channel when a notification is posted.
                  'icon'                    => 'URL', //This is the avatar icon shown in the Slack channel
                                                      //when a notification is posted, overrides the avatar set in the Swarm app.
                  'force_user_header'       => false, //The Slack notification shows the username and avatar only for the first post by a user, default value is false.
             ),
        ),
        'tag_processor' => array(
            'tags' => array(
                'wip' => '/(^|\s)+#wip($|\s)+/i'
            ),
        ),
        'test_definitions' => array(
            'project_and_branch_separator' => ':',
        ),
        'translator' => array(
            'detect_locale'             => true,
            'locale'                    => array("en_GB", "en_US"),
            'translation_file_patterns' => array(),
            'non_utf8_encodings'        => array('sjis', 'euc-jp', 'windows-1252'),
            'utf8_convert' => true,
        ),
        'upgrade' => array(
            'status_refresh_interval' => 10,	//Refresh page every 10 seconds
            'batch_size' => 1000,	//Fetch 1000 reviews to lower memory usage
        ),
        'users' => array(
           'dashboard_refresh_interval' => 300000, //Default 300000 milliseconds
           'display_fullname'           => true,
           'settings' => array(
              'review_preferences' => array(
                  'show_comments_in_files'             => true,
                  'view_diffs_side_by_side'            => true,
                  'show_space_and_new_line_characters' => false,
                  'ignore_whitespace'                  => false,
              ),
              'time_preferences' => array(
                  'display'  => 'Timeago', // Default to 'Timeago' but can be set to 'Timestamp'
              ),
           ),
        ),
        'workflow' => array(
            'enabled' => true, // Switches the workflow feature on. Default is true
        ),
	'xhprof' => array(
            'slow_time'      => 3,
            'ignored_routes' => array('download', 'imagick', 'libreoffice', 'worker'),
        ),
        'saml' => array(...),
    );

  EOF
}
