variable "gke_num_nodes" {
  default     = 1
  description = "number of gke nodes"
}

variable "project" {
  description = "project"
}

variable "region" {
  description = "region"
}

variable "zone" {
  type = string
}

variable "prefix" {
  type = string
}

variable "num_instances" {
  type = string
}

variable "preemptible" {
  type = bool
}