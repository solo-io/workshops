variable "prefix" {
  type = string
}

variable "num_instances" {
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