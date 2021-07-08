module "vm-image" {
  source   = "./gce/vm-image"
  for_each = var.environments

  prefix       = each.key
  vm_image     = lookup(each.value, "vm_image", var.vm_image)
  project      = lookup(each.value, "project", var.project)
  machine_type = lookup(each.value, "machine_type", var.machine_type)
  zone         = lookup(each.value, "zone", var.zone)
}

module "vm-replica" {
  source   = "./gce/vm-replica"
  for_each = var.environments

  prefix               = each.key
  project              = lookup(each.value, "project", var.project)
  machine_type         = lookup(each.value, "machine_type", var.machine_type)
  zone                 = lookup(each.value, "zone", var.zone)
  num_instances        = lookup(each.value, "num_instances", var.num_instances)
  source_machine_image = module.vm-image[each.key].gce_vm_name
}

module "eks-cluster" {
  source   = "./aws/eks"
  for_each = var.eks_clusters

  prefix             = each.key
  num_instances      = lookup(each.value, "num_instances", var.num_instances)
  azs_controlplane   = lookup(each.value, "azs_controlplane", var.azs_controlplane)
  azs_workers        = lookup(each.value, "azs_workers", var.azs_workers)
  eks_version        = lookup(each.value, "eks_version", var.eks_version)
  node_instance_type = lookup(each.value, "node_instance_type", var.node_instance_type)
  # An exact number of 3 kubeconfigs per vm is the only supported choice, as we must use these names: [mgmt, cluster1, cluster2]
  vm_merge_kubeconfig     = length(lookup(each.value, "include_vm", var.include_vm)) > 0 ? 3 : -1
  vm_machine_type         = lookup(lookup(each.value, "include_vm", var.include_vm), "machine_type", var.machine_type)
  vm_source_machine_image = lookup(lookup(each.value, "include_vm", var.include_vm), "source_machine_image", var.vm_image)
  vm_project              = lookup(lookup(each.value, "include_vm", var.include_vm), "project", var.project)
  vm_zone                 = lookup(lookup(each.value, "include_vm", var.include_vm), "zone", var.zone)
}

module "gke-cluster" {
  source   = "./gce/gke"
  for_each = var.gke_clusters

  prefix        = each.key
  project       = lookup(each.value, "project", var.project)
  region        = lookup(each.value, "region", var.region)
  zone          = lookup(each.value, "zone", var.zone)
  preemptible   = lookup(each.value, "preemptible", var.preemptible)
  num_instances = lookup(each.value, "num_instances", var.num_instances)
}