variable "organisation" {
  default = "asmigar"
  type = string
  description = "org name to use as s3 bucket prefix"
}

variable "envs" {
  default     = ["dev"]
  type        = list(string)
  description = "list of environments to be created"
}