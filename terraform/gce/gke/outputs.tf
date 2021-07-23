output "cluster_name" {
  value       = google_container_cluster.primary.*.name
  description = "GKE Cluster Name"
}

output "cluster_host" {
  value       = google_container_cluster.primary.*.endpoint
  description = "GKE Cluster Host"
}
