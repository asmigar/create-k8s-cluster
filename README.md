## Pre-requisite
- Install [terraform v1.5.5](https://www.terraform.io/downloads.html)
- Setup the [aws cli credentials](https://docs.aws.amazon.com/cli/latest/userguide/cli-chap-configure.html) with `default` profile name.

## Setup

1. Apply the terraform project.
```bash
terraform init; terraform apply
```
This will create one k8s master/control-plane node along with two worker nodes.  

This will output
* ssh commands to access the swarm nodes.

3. Ssh into the k8s master node(ssh command details available in terraform apply output from step 2) 
4. [**Run on Manager Node**] Get the join-token and ca cert hash:
```bash
$ kubeadm token list
openssl x509 -pubkey -in /etc/kubernetes/pki/ca.crt | openssl rsa -pubin -outform der 2>/dev/null | \
   openssl dgst -sha256 -hex | sed 's/^.* //'
```

5. Copy the token and cert sha.

6. Ssh into worker nodes(_ssh command details available in terraform apply output from step 2_) 
7. [**Run on all workers nodes**]Run join token command along with token&hash(_copied from step 4_). `control-plane-host` is the private ip of the master node.
```bash
kubeadm join --token <token> <control-plane-host>:6443 --discovery-token-ca-cert-hash sha256:<hash>
```
