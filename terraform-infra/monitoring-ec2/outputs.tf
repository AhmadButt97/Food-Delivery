output "instance_public_ip" {
  value = aws_instance.monitoring.public_ip
}

output "instance_id" {
  value = aws_instance.monitoring.id
}
