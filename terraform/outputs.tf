output "workshop_credentials" {
  value = {
    user: "solo"
    password: "Workshop1#"
  }
}

output "gce_source_vm_name" {
  value = {
    for k, v in module.vm-image : k => v.gce_vm_name
  }
}

output "gce_replicas_public_ip" {
  value = {
    for k, v in module.vm-replica : k => v.gce_public_ip
  }
}
