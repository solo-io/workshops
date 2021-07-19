variable "prefix" {
  type = string
}

variable "project" {
  type = string
}

variable "machine_type" {
  type = string
}

variable "zone" {
  type = string
}

variable "num_instances" {
  type = string
}

variable "source_machine_image" {
  type = string
}

locals {
  ssh_file = "./lab.pub"
}

locals {
  common_tags = {
    created_by = "terraform"
    workspace  = terraform.workspace
    prefix     = var.prefix
  }
}