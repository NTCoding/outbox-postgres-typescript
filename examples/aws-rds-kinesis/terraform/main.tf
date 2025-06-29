terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.30"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "db_password" {
  description = "Database password"
  type        = string
  sensitive   = true
}



# IAM Roles for DMS
resource "aws_iam_role" "dms_vpc_role" {
  name = "dms-vpc-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "dms.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "dms_vpc_role_policy" {
  role       = aws_iam_role.dms_vpc_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonDMSVPCManagementRole"
}

resource "aws_iam_role" "dms_kinesis_role" {
  name = "dms-kinesis-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "dms.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "dms_kinesis_policy" {
  name = "dms-kinesis-policy"
  role = aws_iam_role.dms_kinesis_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "kinesis:PutRecord",
          "kinesis:PutRecords",
          "kinesis:DescribeStream",
          "kinesis:DescribeStreamSummary",
          "kinesis:ListStreams"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_kinesis_stream" "outbox_stream" {
  name        = "outbox-stream"
  shard_count = 1

  tags = {
    Environment = "demo"
  }
}


resource "aws_db_parameter_group" "postgres" {
  family = "postgres17"
  name   = "outbox-demo-postgres-params"

  parameter {
    name         = "rds.logical_replication"
    value        = "1"
    apply_method = "pending-reboot"
  }

  tags = {
    Name = "outbox-demo-postgres-params"
  }
}

resource "aws_db_instance" "postgres" {
  identifier = "outbox-demo-postgres"
  
  engine         = "postgres"
  engine_version = "17.5"
  instance_class = "db.t3.micro"
  
  allocated_storage = 20
  storage_type      = "gp2"
  
  db_name  = "outbox_aws_demo"
  username = "postgres"
  password = var.db_password
  
  
  parameter_group_name = aws_db_parameter_group.postgres.name
  
  publicly_accessible = true
  
  skip_final_snapshot = true
  
  enabled_cloudwatch_logs_exports = ["postgresql"]
  
  tags = {
    Name = "Outbox Demo PostgreSQL"
  }
}

resource "null_resource" "rds_reboot" {
  triggers = {
    parameter_group = aws_db_parameter_group.postgres.id
  }

  provisioner "local-exec" {
    command = "aws rds reboot-db-instance --db-instance-identifier ${aws_db_instance.postgres.identifier} --region ${var.aws_region}"
  }

  depends_on = [aws_db_instance.postgres]
}


resource "aws_dms_replication_instance" "main" {
  replication_instance_class  = "dms.t3.micro"
  replication_instance_id     = "outbox-demo-dms"
  publicly_accessible         = true

  tags = {
    Name = "outbox-demo-dms"
  }
}


resource "aws_dms_endpoint" "source" {
  endpoint_id   = "outbox-demo-source"
  endpoint_type = "source"
  engine_name   = "postgres"
  
  server_name = aws_db_instance.postgres.address
  port        = 5432
  database_name = aws_db_instance.postgres.db_name
  username    = aws_db_instance.postgres.username
  password    = var.db_password

  ssl_mode = "none"

  extra_connection_attributes = "captureDDLs=Y;heartbeatEnable=true;heartbeatSchema=public;heartbeatFrequency=30;"

  depends_on = [aws_db_instance.postgres]

  tags = {
    Name = "outbox-demo-source-endpoint"
  }
}

resource "aws_dms_endpoint" "target" {
  endpoint_id   = "outbox-demo-target"
  endpoint_type = "target"
  engine_name   = "kinesis"
  
  kinesis_settings {
    stream_arn              = aws_kinesis_stream.outbox_stream.arn
    message_format          = "json"
    service_access_role_arn = aws_iam_role.dms_kinesis_role.arn
  }

  depends_on = [aws_kinesis_stream.outbox_stream, aws_iam_role.dms_kinesis_role]

  tags = {
    Name = "outbox-demo-target-endpoint"
  }
}

resource "aws_dms_replication_task" "outbox" {
  migration_type           = "cdc"
  replication_instance_arn = aws_dms_replication_instance.main.replication_instance_arn
  replication_task_id      = "outbox-demo-task"
  start_replication_task   = false
  
  source_endpoint_arn = aws_dms_endpoint.source.endpoint_arn
  target_endpoint_arn = aws_dms_endpoint.target.endpoint_arn
  
  table_mappings = jsonencode({
    rules = [
      {
        rule-type = "selection"
        rule-id   = "1"
        rule-name = "1"
        object-locator = {
          schema-name = "public"
          table-name  = "outbox"
        }
        rule-action = "include"
      }
    ]
  })

  replication_task_settings = jsonencode({
    Logging = {
      EnableLogging = true
      LogComponents = [
        { Id = "SOURCE_UNLOAD", Severity = "LOGGER_SEVERITY_DEFAULT" },
        { Id = "TARGET_LOAD", Severity = "LOGGER_SEVERITY_DEFAULT" },
        { Id = "TASK_MANAGER", Severity = "LOGGER_SEVERITY_DEFAULT" }
      ]
    }
  })

  depends_on = [aws_dms_replication_instance.main, aws_dms_endpoint.source, aws_dms_endpoint.target]

  tags = {
    Name = "outbox-demo-replication-task"
  }
}

output "rds_endpoint" {
  value = aws_db_instance.postgres.address
}

output "kinesis_stream_name" {
  value = aws_kinesis_stream.outbox_stream.name
}