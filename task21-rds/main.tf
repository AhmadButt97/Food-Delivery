terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

# --- Security Group: only allow MySQL (3306) from your IP, not the world ---
resource "aws_security_group" "rds_sg" {
  name        = "food-delivery-tf-rds-sg"
  description = "Allow MySQL access to Terraform-managed RDS instance"
  vpc_id      = var.vpc_id

  ingress {
    description = "MySQL from allowed IP"
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = [var.allowed_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "food-delivery-tf-rds-sg"
  }
}

# --- DB Subnet Group: uses default VPC's existing subnets, no new networking ---
resource "aws_db_subnet_group" "rds_subnet_group" {
  name       = "food-delivery-tf-db-subnet-group"
  subnet_ids = var.subnet_ids

  tags = {
    Name = "food-delivery-tf-db-subnet-group"
  }
}

# --- RDS Instance ---
resource "aws_db_instance" "food_delivery_db" {
  identifier     = var.db_instance_identifier
  engine         = var.db_engine
  engine_version = var.db_engine_version
  instance_class = var.db_instance_class

  allocated_storage = var.db_allocated_storage
  storage_type      = "gp2"

  db_name  = var.db_name
  username = local.db_creds.username
  password = local.db_creds.password

  db_subnet_group_name   = aws_db_subnet_group.rds_subnet_group.name
  vpc_security_group_ids = [aws_security_group.rds_sg.id]

  publicly_accessible = var.publicly_accessible
  skip_final_snapshot = true

  backup_retention_period = 1

  tags = {
    Name      = "food-delivery-tf-db"
    ManagedBy = "Terraform"
  }
}
