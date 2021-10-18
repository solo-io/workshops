output "gce_vm_name" {
  value = var.source_machine_image == "" ? google_compute_image.image.0.name : var.source_machine_image
}
