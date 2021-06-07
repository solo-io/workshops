output "gce_source_public_ip" {
  value = {
    for k, v in module.vm-image : k => v.gce_public_ip
  }
}

output "gce_replicas_public_ip" {
  value = {
    for k, v in module.vm-replica : k => v.gce_public_ip
  }
}
