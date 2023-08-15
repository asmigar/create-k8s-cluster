provider "aws" {
	region  = "us-east-1"
	profile = "default"
	default_tags {
		tags = {
			Organisation = "Asmigar"
			Environment  = "dev"
		}
	}
}

data "http" "my_public_ip" {
	url = "https://ifconfig.me"
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
		cidr_blocks = ["${data.http.my_public_ip.response_body}/32"]
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
	key_name   = var.shh_key_name
	public_key = tls_private_key.this.public_key_openssh

	provisioner "local-exec" {
		command = "echo '${tls_private_key.this.private_key_openssh}' > ~/.ssh/${var.shh_key_name}.pem; chmod 400 ~/.ssh/${self.key_name}.pem"
	}

	provisioner "local-exec" {
		when    = destroy
		command = "rm -rf ~/.ssh/${self.key_name}.pem"
	}
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
		swapoff -a
		sed -i.bak -r 's/(.+ swap .+)/#\1/' /etc/fstab
		wget https://github.com/containerd/containerd/releases/download/v1.7.3/containerd-1.7.3-linux-arm64.tar.gz
		tar Cxzvf /usr/local containerd-1.7.3-linux-arm64.tar.gz
		wget https://raw.githubusercontent.com/containerd/containerd/main/containerd.service \
		-O /usr/lib/systemd/system/containerd.service
		systemctl daemon-reload
		systemctl enable --now containerd
		wget https://github.com/opencontainers/runc/releases/download/v1.1.8/runc.arm64
		install -m 755 runc.arm64 /usr/local/sbin/runc
		wget https://github.com/containernetworking/plugins/releases/download/v1.3.0/cni-plugins-linux-arm-v1.3.0.tgz
		mkdir -p /opt/cni/bin
		tar Cxzvf /opt/cni/bin cni-plugins-linux-arm-v1.3.0.tgz
		mkdir -p /etc/containerd
		containerd config default > /etc/containerd/config.toml
		sed -i.bak 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
		sed -i.bak 's/sandbox_image = "registry.k8s.io\/pause:3.8"/sandbox_image = "registry.k8s.io\/pause:3.9"/' /etc/containerd/config.toml
		systemctl restart containerd
		cat <<-K8SCONF | sudo tee /etc/modules-load.d/k8s.conf
		overlay
		br_netfilter
		K8SCONF
		modprobe overlay
		modprobe br_netfilter
		cat <<SYSCTLK8SCONF | sudo tee /etc/sysctl.d/k8s.conf
		net.bridge.bridge-nf-call-iptables  = 1
		net.bridge.bridge-nf-call-ip6tables = 1
		net.ipv4.ip_forward                 = 1
		SYSCTLK8SCONF
		sysctl --system
		cat <<K8SREPO | sudo tee /etc/yum.repos.d/kubernetes.repo
		[kubernetes]
		name=Kubernetes
		baseurl=https://packages.cloud.google.com/yum/repos/kubernetes-el7-\$basearch
		enabled=1
		gpgcheck=1
		gpgkey=https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
		exclude=kubelet kubeadm kubectl
		K8SREPO
		setenforce 0
		sed -i 's/^SELINUX=enforcing$/SELINUX=permissive/' /etc/selinux/config
		yum install -y kubelet kubeadm kubectl --disableexcludes=kubernetes
		systemctl enable --now kubelet
		kubeadm init --pod-network-cidr 192.168.0.0/16
		curl https://raw.githubusercontent.com/projectcalico/calico/v3.26.1/manifests/calico.yaml -O
		kubectl --kubeconfig='/etc/kubernetes/admin.conf' apply -f calico.yaml
		EOT
}

resource "aws_instance" "worker" {
  count         = var.workers
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
		swapoff -a
		sed -i.bak -r 's/(.+ swap .+)/#\1/' /etc/fstab
		wget https://github.com/containerd/containerd/releases/download/v1.7.3/containerd-1.7.3-linux-arm64.tar.gz
		tar Cxzvf /usr/local containerd-1.7.3-linux-arm64.tar.gz
		wget https://raw.githubusercontent.com/containerd/containerd/main/containerd.service \
		-O /usr/lib/systemd/system/containerd.service
		systemctl daemon-reload
		systemctl enable --now containerd
		wget https://github.com/opencontainers/runc/releases/download/v1.1.8/runc.arm64
		install -m 755 runc.arm64 /usr/local/sbin/runc
		wget https://github.com/containernetworking/plugins/releases/download/v1.3.0/cni-plugins-linux-arm-v1.3.0.tgz
		mkdir -p /opt/cni/bin
		tar Cxzvf /opt/cni/bin cni-plugins-linux-arm-v1.3.0.tgz
		mkdir -p /etc/containerd
		containerd config default > /etc/containerd/config.toml
		sed -i.bak 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
		sed -i.bak 's/sandbox_image = "registry.k8s.io\/pause:3.8"/sandbox_image = "registry.k8s.io\/pause:3.9"/' /etc/containerd/config.toml
		systemctl restart containerd
		cat <<-K8SCONF | sudo tee /etc/modules-load.d/k8s.conf
		overlay
		br_netfilter
		K8SCONF
		modprobe overlay
		modprobe br_netfilter
		cat <<SYSCTLK8SCONF | sudo tee /etc/sysctl.d/k8s.conf
		net.bridge.bridge-nf-call-iptables  = 1
		net.bridge.bridge-nf-call-ip6tables = 1
		net.ipv4.ip_forward                 = 1
		SYSCTLK8SCONF
		sysctl --system
		cat <<K8SREPO | sudo tee /etc/yum.repos.d/kubernetes.repo
		[kubernetes]
		name=Kubernetes
		baseurl=https://packages.cloud.google.com/yum/repos/kubernetes-el7-\$basearch
		enabled=1
		gpgcheck=1
		gpgkey=https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
		exclude=kubelet kubeadm kubectl
		K8SREPO
		setenforce 0
		sed -i 's/^SELINUX=enforcing$/SELINUX=permissive/' /etc/selinux/config
		yum install -y kubelet kubeadm kubectl --disableexcludes=kubernetes
		systemctl enable --now kubelet
		EOT
}
