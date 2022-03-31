variable "prefix" {
  type = string
}

variable "num_instances" {
  type = string
}

variable "aws_lb_controller" {
  type = string
}

variable "azs_controlplane" {
  type = list(string)
}

variable "azs_workers" {
  type = list(string)
}

variable "eks_version" {
  type = string
}

variable "node_instance_type" {
  type = string
}

variable "vm_merge_kubeconfig" {
  type = string
}

variable "vm_machine_type" {
  type = string
}

variable "vm_source_machine_image" {
  type = string
}

variable "vm_project" {
  type = string
}

variable "vm_zone" {
  type = string
}

locals {
  common_tags = {
    created_by = "terraform"
    workspace  = terraform.workspace
    prefix     = var.prefix
  }
}