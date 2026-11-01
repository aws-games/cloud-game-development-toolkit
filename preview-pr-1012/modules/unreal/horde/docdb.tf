resource "aws_docdb_subnet_group" "horde" {
  count = var.database_connection_string == null ? 1 : 0

  name       = "${var.name}-docdb-subnet-group"
  subnet_ids = var.unreal_horde_service_subnets

  tags = {
    Name = "Horde DocumentDB subnet group"
  }
}

resource "aws_docdb_cluster_parameter_group" "horde" {
  count = var.database_connection_string == null ? 1 : 0

  family      = "docdb5.0"
  name        = "${var.name}-docdb-parameter-group"
  description = "Horde DocumentDb cluster parameter group"
  #checkov:skip=CKV_AWS_104:Audit logs will be enabled through variable

  parameter {
    name  = "tls"
    value = "enabled"
  }
}

resource "aws_docdb_cluster_instance" "horde" {
  count = var.database_connection_string == null ? var.docdb_instance_count : 0

  identifier         = "${var.name}-docdb-${count.index}"
  cluster_identifier = aws_docdb_cluster.horde[0].id
  instance_class     = var.docdb_instance_class
}

resource "aws_docdb_cluster" "horde" {
  count = var.database_connection_string == null ? 1 : 0

  #checkov:skip=CKV_AWS_182:CMK encryption not currently supported
  #checkov:skip=CKV_AWS_85:Logging will be enabled by variable
  cluster_identifier      = "${var.name}-docdb-cluster"
  engine                  = "docdb"
  master_username         = var.docdb_master_username
  master_password         = var.docdb_master_password
  backup_retention_period = var.docdb_backup_retention_period
  preferred_backup_window = var.docdb_preferred_backup_window
  skip_final_snapshot     = var.docdb_skip_final_snapshot

  db_cluster_parameter_group_name = aws_docdb_cluster_parameter_group.horde[0].name
  db_subnet_group_name            = aws_docdb_subnet_group.horde[0].name
  vpc_security_group_ids          = [aws_security_group.unreal_horde_docdb_sg[0].id]
  storage_encrypted               = var.docdb_storage_encrypted
}
