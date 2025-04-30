# #######################################
# # TeamCity Aurora Serverless Database #
# #######################################

# Subnet group
resource "aws_db_subnet_group" "teamcity_db_subnet_group" {
  count      = var.database_connection_string == null ? 1 : 0
  name       = "${local.name_prefix}-db-subnet-group"
  subnet_ids = var.service_subnets
  tags       = local.tags
}

# # RDS instance with Aurora serverless engine
resource "aws_rds_cluster" "teamcity_db_cluster" {
  #checkov:skip=CKV2_AWS_27:not enabling query logging by design
  #checkov:skip=CKV2_AWS_8: TODO: add rds backup plan
  count                       = var.database_connection_string == null ? 1 : 0
  cluster_identifier          = "teamcity-cluster"
  engine                      = "aurora-postgresql"
  engine_mode                 = "provisioned"
  engine_version              = "16.6" #check for latest as option
  database_name               = "teamcity"
  master_username             = "teamcity"
  manage_master_user_password = true #using AWS Secrets Manager
  storage_encrypted           = true
  skip_final_snapshot         = var.aurora_skip_final_snapshot
  db_subnet_group_name        = aws_db_subnet_group.teamcity_db_subnet_group[0].id
  vpc_security_group_ids = [
    aws_security_group.teamcity_db_sg[0].id
  ]

  serverlessv2_scaling_configuration {
    max_capacity             = 1.0
    min_capacity             = 0.0
    seconds_until_auto_pause = 3600
  }
}

resource "aws_rds_cluster_instance" "teamcity_db_cluster_instance" {
  count              = var.database_connection_string == null ? var.aurora_instance_count : 0
  cluster_identifier = aws_rds_cluster.teamcity_db_cluster[0].id
  instance_class     = "db.serverless"
  engine             = aws_rds_cluster.teamcity_db_cluster[0].engine
  engine_version     = aws_rds_cluster.teamcity_db_cluster[0].engine_version
}