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

variable "num_instances" {
  type = string
}

variable "environments" {
  type = map(any)
}
