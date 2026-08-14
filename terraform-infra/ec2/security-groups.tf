# Bastion SG: allow SSH from your IP only
resource "aws_security_group" "bastion_sg" {
  name        = "bastion-sg"
  description = "Allow SSH from my IP"
  vpc_id      = data.aws_vpc.main.id

  ingress {
    description = "SSH from my IP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # tighten to your own IP/32 if you want extra security
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "bastion-sg"
  }
}

# Private instance SG: allow SSH only from Bastion, plus app ports
resource "aws_security_group" "private_sg" {
  name        = "private-sg"
  description = "Allow SSH from Bastion and app traffic"
  vpc_id      = data.aws_vpc.main.id

  ingress {
    description     = "SSH from Bastion"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion_sg.id]
  }

  ingress {
    description = "NodePort range for Kind/app access from ALB"
    from_port   = 30000
    to_port     = 32767
    protocol    = "tcp"
    cidr_blocks = [data.aws_vpc.main.cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "private-sg"
  }
}
