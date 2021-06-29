output "cluster_name" {
  value = module.eks.*.cluster_name
}

output "kubeconfig" {
  value = module.eks.*.kubeconfig
}