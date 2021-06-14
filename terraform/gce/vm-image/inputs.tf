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

variable "vm_image" {
  type = string
}

locals {
  ssh_file = "./lab.pub"
}
