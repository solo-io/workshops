# VPC
resource "google_compute_network" "vpc" {
  count                   = var.num_instances
  project                 = var.project
  name                    = "${terraform.workspace}-${var.prefix}-${count.index + 1}"
  auto_create_subnetworks = "false"
}

# Subnet
resource "google_compute_subnetwork" "subnet" {
  count         = var.num_instances
  project       = var.project
  name          = "${terraform.workspace}-${var.prefix}-${count.index + 1}"
  region        = var.region
  network       = google_compute_network.vpc[count.index].name
  ip_cidr_range = "10.10.0.0/24"
}

# GKE cluster
resource "google_container_cluster" "primary" {
  count    = var.num_instances
  project  = var.project
  name     = "${terraform.workspace}-${var.prefix}-${count.index + 1}"
  location = var.zone

  # We can't create a cluster with no node pool defined, but we want to only use
  # separately managed node pools. So we create the smallest possible default
  # node pool and immediately delete it.
  remove_default_node_pool = true
  initial_node_count       = 1

  network    = google_compute_network.vpc[count.index].name
  subnetwork = google_compute_subnetwork.subnet[count.index].name

  resource_labels = {
    generated-by = "terraform"
    workspace    = terraform.workspace
    when         = lower(formatdate("MMM-DD-YYYY", timestamp()))
  }

  lifecycle {
    ignore_changes = [
      resource_labels,
    ]
  }
}

# Separately Managed Node Pool
resource "google_container_node_pool" "primary_nodes" {
  count      = var.num_instances
  project    = var.project
  name       = "${google_container_cluster.primary[count.index].name}-node-pool"
  location   = var.zone
  cluster    = google_container_cluster.primary[count.index].name
  node_count = var.gke_num_nodes

  node_config {
    oauth_scopes = [
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring",
    ]

    labels = {
      workspace = terraform.workspace
      prefix    = var.prefix
      instance  = 1
    }

    preemptible  = var.preemptible
    machine_type = "n1-standard-1"
    tags         = ["gke-node", "${terraform.workspace}-${var.prefix}-${count.index + 1}"]
    metadata = {
      disable-legacy-endpoints = "true"
    }
  }
}

resource "local_file" "kubeconfig" {
  count = var.num_instances
  content = templatefile("${path.module}/templates/kubeconfig.tpl", {
    password               = "${google_container_cluster.primary[count.index].master_auth[0].password}"
    username               = "${google_container_cluster.primary[count.index].master_auth[0].username}"
    cluster_ca_certificate = "${google_container_cluster.primary[count.index].master_auth[0].cluster_ca_certificate}"
    endpoint               = "${google_container_cluster.primary[count.index].endpoint}"
    suffix                 = "${google_container_cluster.primary[count.index].name}"
  })
  filename = "${path.root}/output/gke/${google_container_cluster.primary[count.index].name}/original-kubeconfig"

  provisioner "local-exec" {
    command = <<COMMAND
      cp ${path.root}/output/gke/${google_container_cluster.primary[count.index].name}/original-kubeconfig ${path.root}/output/gke/${google_container_cluster.primary[count.index].name}/full-kubeconfig \
      && export KUBECONFIG=${path.root}/output/gke/${google_container_cluster.primary[count.index].name}/full-kubeconfig \
      && kubectl apply -f ${path.module}/templates/gke-admin.yaml \
      && TOKEN=$(kubectl describe -n kube-system secrets "$(kubectl describe -n kube-system serviceaccount gke-admin | grep -i Tokens | awk '{print $2}')" | grep token: | awk '{print $2}') \
      && kubectl config set-credentials workshop --token=$TOKEN \
      && kubectl config set-context workshop --cluster=${google_container_cluster.primary[count.index].name} --user=workshop \
      && kubectl config use-context workshop \
      && kubectl config view --flatten --minify > ${path.root}/output/gke/${google_container_cluster.primary[count.index].name}/guest-kubeconfig
    COMMAND
  }

}
