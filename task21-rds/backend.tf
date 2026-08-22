terraform {
  backend "s3" {
    bucket         = "miseacademy-task21-tfstate-746413875412"
    key            = "task21-rds/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-locks-task21"
    encrypt        = true
  }
}
