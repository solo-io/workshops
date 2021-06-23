# Default parameters
project       = "solo-test-236622"
machine_type  = "n1-standard-1"
zone          = "europe-west4-a"
vm_image      = "ubuntu-2004-focal-v20210510"
num_instances = 1

#EKS
azs_controlplane   = ["eu-west-1a", "eu-west-1b", "eu-west-1c"]
azs_workers        = ["eu-west-1a", "eu-west-1b", "eu-west-1c"]
eks_version        = "1.20"
node_instance_type = "t3.small"

# TO BE EDITED #
environments = {
  #workshop1 = {
  #  machine_type  = "n1-standard-8"
  #  zone          = "europe-west4-a"
  #  num_instances = 0
  #  vm_image      = "ubuntu-2004-focal-v20210211"
  #}
  personal1 = {
    num_instances = 1
    machine_type  = "n1-standard-8"
  }
}

#eks_clusters = {
#  workshop-a = {
#    num_instances = 2
#    azs_workers   = ["eu-west-1a"]
#  }
#  workshop-b = {
#    num_instances = 2
#    azs_workers   = ["eu-west-1b"]
#  }
#}
