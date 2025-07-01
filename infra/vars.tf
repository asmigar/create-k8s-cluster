variable "vpc_cidr_block" {
  type    = string
  default = "10.0.0.0/16"
}

variable "public_subnet_cidr_block" {
  type    = string
  default = "10.0.1.0/24"
}

variable "ssh_key_name" {
  type        = string
  default     = "k8s"
  description = "ssh key name to be created in EC2 and store in ~/.ssh folder"
}

variable "workers" {
    type = number
    default = 2
    description = "number of worker nodes"
}

variable "env" {
  type = string
  default = "dev"
  description = "The environment to be used"
}