# Copy this file to configuration.auto.tfvars and uncomment values
# If you use any other name, please make sure you DONT commit/push the file with credentials

#######################################################################
# GCP
# project       = "solo-test-236622"
# region        = "europe-west4"
# zone          = "europe-west4-a"

#######################################################################
# AWS
# default_region = "eu-west-1"

# And don't forget to provide credentials:
# gcloud auth application-default login
# aws configure

#######################################################################
# GCP Virtual Machines
# machine_type  = "n1-standard-1"
# vm_image      = "ubuntu-2004-focal-v20210510"
# num_instances = 0

#environments = {
#  workshop1 = {
#    machine_type         = "n1-standard-8"
#    zone                 = "europe-west4-a"
#    num_instances        = 0
#    source_machine_image = "workshop-generic-v20211217"
#  }
#  personal1 = {
#    num_instances = 1
#    machine_type  = "n1-standard-8"
#  }
#}

#######################################################################
# GKE
# preemptible = false # to build clusters that live mostly for 24h, cheaper

#gke_clusters = {
#  workshop-b = {
#    num_instances = 1
#    zone          = "europe-west4-a"
#  }
#}

#######################################################################
# EKS
#azs_controlplane   = ["eu-west-1a", "eu-west-1b", "eu-west-1c"]
#azs_workers        = ["eu-west-1a", "eu-west-1b", "eu-west-1c"]
#eks_version        = "1.21"
#node_instance_type = "t3.small"
#include_vm         = {}
#
#eks_clusters = {
#  eks-batch1 = {
#    num_instances      = 3
#    node_instance_type = "t3.micro"
#    aws_lb_controller = 0 # Only works woth 1 cluster, and setting the env KUBE_CONFIG_PATH=/{}/output/{}/kubeconfig
#    include_vm = {
#      machine_type         = "n1-standard-1"
#      source_machine_image = "jesus-test-personal1-source-image"
#      region               = "europe-west1"
#      zone                 = "europe-west1-d"
#    }
#  }
#}
