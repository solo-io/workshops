output "cluster_name" {
  value = module.eks.*.cluster_name
}

output "kubeconfig" {
  value = module.eks.*.kubeconfig
}

output "gce_replicas_public_ip" {
  value = {
    for k, v in module.vm-replica : k => v.gce_public_ip
  }
}