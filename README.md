## Pre-requisite
- Install [terraform v1.5.5](https://www.terraform.io/downloads.html)
- Setup the [aws cli credentials](https://docs.aws.amazon.com/cli/latest/userguide/cli-chap-configure.html) with `default` profile name.


## Create Remote State
Terraform keeps all the info about the resources in a state file. Rather than keeping it on local disk, we store it on S3 bucket.
To learn more read the docs [here](https://developer.hashicorp.com/terraform/language/settings/backends/s3).

Run below terraform command to create remote state bucket on your AWS account. This will also prompt for your aws cli user mentioned in [Pre-requisties](#pre-requisites)
```bash
cd remote_state; terraform init; terraform apply --auto-approve
```

The above command will output the s3 bucket name. These will be needed later. For example,
```bash
Outputs:
state_bucket = "asmigar-create-k8s-terraform-state"
```

## Create Infra
Run below command to create EC2 instances i.e. one k8s master/control-plane node along with two worker nodes. This will even output the ssh command to access the instance.
```bash
cd infra; terraform init; terraform apply --auto-approve
```

## Provision Infra
1. Run ansible playbook to setup kubernetes on created infra.
```bash
cd infra/provisioning; ansible-playbook playbook.yml -i inventory.ini 
```

2. Ssh into the k8s master node(ssh command details available in terraform apply output from step 2) 
3. [**Run on Manager Node**] Get the join-token and ca cert hash:
```bash
kubeadm token list
openssl x509 -pubkey -in /etc/kubernetes/pki/ca.crt | openssl rsa -pubin -outform der 2>/dev/null | \
   openssl dgst -sha256 -hex | sed 's/^.* //'
```

4. Copy the token and cert sha.

5. Ssh into worker nodes(_ssh command details available in terraform apply output from step 2_) 
6. [**Run on all workers nodes**]Run join token command along with token&hash(_copied from step 4_). `control-plane-host` is the private ip of the master node.
```bash
kubeadm join --token <token> <control-plane-host>:6443 --discovery-token-ca-cert-hash sha256:<hash>
```

## TODO 
- Get rid of huge shell scripts. Create ansible scripts for installing/setting Kubernetes on instances. 