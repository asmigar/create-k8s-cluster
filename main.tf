provider "aws" {
  region  = "us-east-1"
  profile = "default"
  default_tags {
    tags = {
      Organisation = "Cloudtrain"
      Environment  = "dev"
    }
  }
}

resource "aws_security_group" "allow_ssh" {
  name        = "allow_tls"
  description = "Allow TLS inbound traffic"
  vpc_id      = aws_vpc.main.id

  ingress {
    description      = "ssh"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  ingress {
    description      = "kubelet api"
    from_port        = 10250
    to_port          = 10250
    protocol         = "tcp"
    cidr_blocks      = [aws_subnet.public.cidr_block]
  }

  ingress {
    description      = "kubenetes api"
    from_port        = 6443
    to_port          = 6443
    protocol         = "tcp"
    cidr_blocks      = [aws_subnet.public.cidr_block]
  }
  
  egress {
    from_port        = 0
    to_port          = 65535
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]

  }

  tags = {
    Name = "allow_ssh"
  }
}



resource "tls_private_key" "this" {
  algorithm = "RSA"
  rsa_bits  = 4096

  provisioner "local-exec" {
    command = "echo '${self.private_key_openssh}' > ~/.ssh/${var.shh_key_name}.pem; chmod 400 ~/.ssh/docker_swarm.pem"
  }

  provisioner "local-exec" {
    when = destroy
    command = "rm -rf ~/.ssh/${var.shh_key_name}.pem"
  }
}

resource "aws_key_pair" "this" {
  key_name   = var.shh_key_name
  public_key = tls_private_key.this.public_key_openssh
}

resource "aws_instance" "master" {
  ami           = "ami-0006abfd85caddf82"
  instance_type = "t4g.small"

  tags = {
    Name = "master"
  }

  vpc_security_group_ids = [aws_security_group.allow_ssh.id]
  subnet_id              = aws_subnet.public.id
  key_name               = aws_key_pair.this.key_name
  user_data              = <<-EOT
		#!/bin/bash
		EOT
}

resource "aws_instance" "worker" {
  count         = 2
  ami           = "ami-0006abfd85caddf82"
  instance_type = "t4g.small"

  tags = {
    Name = "worker-${count.index}"
  }

  vpc_security_group_ids = [aws_security_group.allow_ssh.id]
  subnet_id              = aws_subnet.public.id
  key_name               = aws_key_pair.this.key_name
  user_data              = <<-EOT
		#!/bin/bash
		EOT
}
