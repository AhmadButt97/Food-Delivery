output "db_endpoint" {
  value = aws_db_instance.food_delivery_db.endpoint
}
output "db_address" {
  value = aws_db_instance.food_delivery_db.address
}
output "db_port" {
  value = aws_db_instance.food_delivery_db.port
}
output "db_name" {
  value = aws_db_instance.food_delivery_db.db_name
}
output "db_security_group_id" {
  value = aws_security_group.rds_sg.id
}
