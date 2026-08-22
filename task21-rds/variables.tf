variable "aws_region" {
  type    = string
  default = "us-east-1"
}
variable "db_instance_identifier" {
  type    = string
  default = "food-delivery-tf-db"
}
variable "db_name" {
  type    = string
  default = "fooddelivery"
}
variable "db_engine" {
  type    = string
  default = "mysql"
}
variable "db_engine_version" {
  type    = string
  default = "8.4"
}
variable "db_instance_class" {
  type    = string
  default = "db.t3.micro"
}
variable "db_allocated_storage" {
  type    = number
  default = 20
}
variable "db_username" {
  type    = string
  default = "dbadmin"
}
variable "vpc_id" {
  type = string
}
variable "subnet_ids" {
  type = list(string)
}
variable "allowed_cidr" {
  type = string
}
variable "publicly_accessible" {
  type    = bool
  default = true
}
