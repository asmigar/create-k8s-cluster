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

resource "aws_key_pair" "webserver" {
  key_name   = "webserver"
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDMK0sHujc2rfg3y4blCK46ye7jMTmDa3jXqGVL68ts87zo95JZdQakLQlLiUkVvm7IYOePctjUZDRtaUgnWPWdC/QYQvLLiAkO/IzgcHIyvURNjpVd94I67afYygzIeagsKQJW+igVeztw95fkwW8gvb2DirM4UkOEN6FnGMjBDOFjTJSu1AKqgzr7cqV7JMdVqDLlODGS6Q++H/xv2WTFNXNBR9NFTtTrxJl5+iFKrtg8D/T+1/5LvUwclDd9un9Jb3SYCtxwRK00I3E1nNSviT1zxsUrtkSMt8B+qngwUGjT5whIdpV3109qFt9F4/lEbcrpTtuoiH/nCgQYNL7CZMKVn12r0jg/ADOHpqj56sxh81Vx/NWRi4t1H8d7OZ/aQ3pFMtW1fB+kcdvwT1fNJRAW1U1m6rR2yd6QjUR+5jiBLfvpH6PIwdn1OpVPGRtAUIQxkOeRkTeUsAbvBm2PvWSnoAtgLv/8GzlzY00uw0odLlj/RhJlIHYkyXqETTs= sagarmaurya@sagar.local"
}

resource "aws_instance" "master" {
  ami           = "ami-022e1a32d3f742bd8"
  instance_type = "t2.micro"

  tags = {
    Name = "master"
  }

  vpc_security_group_ids = [aws_security_group.allow_ssh.id]
  subnet_id              = aws_subnet.public.id
  key_name               = aws_key_pair.webserver.key_name
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
  key_name               = aws_key_pair.webserver.key_name
  user_data              = <<-EOT
		#!/bin/bash
		EOT
}
