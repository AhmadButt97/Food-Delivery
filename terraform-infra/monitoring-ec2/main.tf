resource "aws_instance" "monitoring" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t3.medium"
  subnet_id              = data.aws_subnets.default.ids[0]
  vpc_security_group_ids = [aws_security_group.monitoring_sg.id]
  key_name               = "food-delivery-key"
  iam_instance_profile   = aws_iam_instance_profile.cloudwatch_profile.name

  root_block_device {
    volume_size = 30
    volume_type = "gp3"
  }

  tags = {
    Name = "monitoring-instance"
  }
}
