# https://www.terraform.io/docs/language/values/variables.html
# Later sources taking precedence over earlier ones:
# 1. Environment variables (TF_VAR_ followed by the name of a declared variable)
# 2. The terraform.tfvars file, if present.
# 3. The terraform.tfvars.json file, if present.
# 4. Any *.auto.tfvars or *.auto.tfvars.json files, processed in lexical order of their filenames.
# 5. Any -var and -var-file options on the command line, in the order they are provided. (terraform apply -var="image_id=ami-abc123")

# GCP
project = "solo-test-236622"
region  = "europe-west4"
zone    = "europe-west4-a"

# AWS
default_region = "eu-west-1"

# GCP VM
machine_type  = "n1-standard-1"
vm_image      = "ubuntu-2004-focal-v20210510"
num_instances = 0

# GKE
preemptible = false # to build clusters that live mostly for 24h, cheaper

# EKS
azs_controlplane   = ["eu-west-1a", "eu-west-1b", "eu-west-1c"]
azs_workers        = ["eu-west-1a", "eu-west-1b", "eu-west-1c"]
eks_version        = "1.21"
node_instance_type = "t3.small"
include_vm         = {}

eks_clusters = {
  eks-batch1 = {
    num_instances      = 3
    node_instance_type = "t3.2xlarge"
  }
}
