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