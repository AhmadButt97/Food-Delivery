# Bastion Host (public subnet)
resource "aws_instance" "bastion" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = "t3.micro"
  subnet_id                   = data.aws_subnet.public.id
  vpc_security_group_ids      = [aws_security_group.bastion_sg.id]
  key_name                    = "food-delivery-key"
  associate_public_ip_address = true

  tags = {
    Name = "food-delivery-bastion"
  }
}

# Private instance (private subnet) — will run Kind cluster
resource "aws_instance" "private" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t3.medium"
  subnet_id              = data.aws_subnet.private.id
  vpc_security_group_ids = [aws_security_group.private_sg.id]
  key_name               = "food-delivery-key"

  root_block_device {
    volume_size = 30
    volume_type = "gp3"
  }

  tags = {
    Name = "food-delivery-private"
  }
}
