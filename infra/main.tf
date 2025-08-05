provider "aws" {
	region  = "us-east-1"
	profile = "asmigar"
	default_tags {
		tags = {
			Organisation = "Asmigar"
			Environment  = var.env
		}
	}
}

data "http" "my_public_ip" {
	url = "https://ipv4.icanhazip.com"
}

resource "aws_security_group" "allow_ssh" {
	name        = "allow_tls"
	description = "Allow TLS inbound traffic"
	vpc_id      = aws_vpc.main.id

	ingress {
		description = "ssh"
		from_port   = 22
		to_port     = 22
		protocol    = "tcp"
		cidr_blocks = ["${chomp(data.http.my_public_ip.response_body)}/32"]
	}

	ingress {
		description = "kubelet api"
		from_port   = 10250
		to_port     = 10250
		protocol    = "tcp"
		cidr_blocks = [aws_subnet.public.cidr_block]
	}

	ingress {
		description = "kubenetes api"
		from_port   = 6443
		to_port     = 6443
		protocol    = "tcp"
		cidr_blocks = [aws_subnet.public.cidr_block]
	}

	ingress {
		description = "calico networking"
		from_port   = 179
		to_port     = 179
		protocol    = "tcp"
		cidr_blocks = [aws_subnet.public.cidr_block]
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
}

resource "aws_key_pair" "this" {
	key_name   = var.ssh_key_name
	public_key = tls_private_key.this.public_key_openssh
}

resource "local_sensitive_file" "ssh_private_key" {
	content         = tls_private_key.this.private_key_openssh
	filename        = pathexpand("~/.ssh/${aws_key_pair.this.key_name}.pem")
	file_permission = "0400"
}

data "aws_ami" "amazon_linux_2023" {
	most_recent = true
	owners      = ["amazon"]

	filter {
		name   = "name"
		values = ["al2023-ami-*"]
	}

	filter {
		name   = "virtualization-type"
		values = ["hvm"]
	}

	filter {
		name   = "architecture"
		values = ["arm64"]
	}
}


resource "aws_instance" "master" {
	ami           = data.aws_ami.amazon_linux_2023.id
	instance_type = "t4g.small"

	tags = {
		Name = "master"
	}

	vpc_security_group_ids = [aws_security_group.allow_ssh.id]
	subnet_id              = aws_subnet.public.id
	key_name               = aws_key_pair.this.key_name

	lifecycle {
		replace_triggered_by = [ aws_key_pair.this ]
	}
}

resource "aws_instance" "worker" {
  count         = var.workers
  ami           = data.aws_ami.amazon_linux_2023.id
  instance_type = "t4g.small"

  tags = {
    Name = "worker-${count.index}"
  }

  vpc_security_group_ids = [aws_security_group.allow_ssh.id]
  subnet_id              = aws_subnet.public.id
  key_name               = aws_key_pair.this.key_name

	lifecycle {
		replace_triggered_by = [ aws_key_pair.this ]
	}
}

resource "local_file" "inventory" {
	filename = "${path.root}/provisioning/inventory.ini"
	content = templatefile("${path.module}/inventory.tftpl", { master_public_dns = aws_instance.master.public_dns , workers_public_dns = aws_instance.worker[*].public_dns , key_name = var.ssh_key_name } )
}