# EKS
azs_controlplane   = ["eu-west-1a", "eu-west-1b", "eu-west-1c"]
azs_workers        = ["eu-west-1a", "eu-west-1b", "eu-west-1c"]
eks_version        = "1.20"
node_instance_type = "t3.small"

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