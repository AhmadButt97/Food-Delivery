
# --- Secrets Manager: fetch DB credentials instead of hardcoding them ---
data "aws_secretsmanager_secret" "rds_credentials" {
  name = "food-delivery/rds/credentials"
}

data "aws_secretsmanager_secret_version" "rds_credentials" {
  secret_id = data.aws_secretsmanager_secret.rds_credentials.id
}

locals {
  db_creds = jsondecode(data.aws_secretsmanager_secret_version.rds_credentials.secret_string)
}
