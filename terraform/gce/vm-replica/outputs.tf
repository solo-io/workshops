output "gce_public_ip" {
  value = google_compute_instance_from_machine_image.tpl[*].network_interface.0.access_config.0.nat_ip
}
