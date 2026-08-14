data "aws_vpc" "main" {
  filter {
    name   = "tag:Name"
    values = ["food-delivery-vpc"]
  }
}

data "aws_subnet" "public" {
  filter {
    name   = "tag:Name"
    values = ["food-delivery-public-subnet"]
  }
}

data "aws_subnet" "private" {
  filter {
    name   = "tag:Name"
    values = ["food-delivery-private-subnet"]
  }
}

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
}
