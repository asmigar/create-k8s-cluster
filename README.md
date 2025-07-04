## Pre-requisite
- Install [terraform v1.5.5](https://www.terraform.io/downloads.html)
- Setup the [aws cli credentials](https://docs.aws.amazon.com/cli/latest/userguide/cli-chap-configure.html) with `asmigar` profile name.


## Create Remote State
Terraform keeps all the info about the resources in a state file. Rather than keeping it on local disk, we store it on S3 bucket.
To learn more read the docs [here](https://developer.hashicorp.com/terraform/language/settings/backends/s3).

Run below terraform command to create remote state bucket on your AWS account. 
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