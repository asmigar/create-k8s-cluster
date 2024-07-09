terraform {
  source = "../../modules//k8s"
}

include "root" {
  path = find_in_parent_folders()
}

inputs = {
  env = "prod"
}
