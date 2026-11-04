provider "aws" {
  region  = "us-east-1"
}

resource "aws_instance" "example_server" {
  ami           = "ami-0d97d7f07b25dd693"
  instance_type = "t2.micro"
  
  tags = {
    Name = "UbuntuTeste"
  }
  
}