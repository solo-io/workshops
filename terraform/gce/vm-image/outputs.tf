output "gce_public_ip" {
  value = google_compute_instance.vm.network_interface.0.access_config.0.nat_ip
}

output "gce_vm_name" {
  value = google_compute_image.image.name
}
