resource "google_compute_instance" "vm" {
  count = var.source_machine_image == "" ? 1 : 0
  project      = var.project
  name         = "${terraform.workspace}-${var.prefix}-source-image"
  machine_type = var.machine_type
  zone         = var.zone

  tags = [var.prefix]

  boot_disk {
    initialize_params {
      image = var.vm_image
      size  = "100"
    }
  }

  network_interface {
    network = "default"

    access_config {
      // Ephemeral IP
    }
  }

  metadata = {
    enable-oslogin = "FALSE"
    ssh-keys       = "solo:${file(local.ssh_file)}"
  }

  lifecycle {
    ignore_changes = [
      machine_type,
      tags
    ]
  }

  # Wait until ip is available
  provisioner "local-exec" {
    command = "echo 'waiting for ip ${self.network_interface.0.access_config.0.nat_ip}' && until nc -z ${self.network_interface.0.access_config.0.nat_ip} 22; do sleep 1; done && sleep 10"
  }

  # Provision machine with ansible
  provisioner "local-exec" {
    command = "ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -u solo -i '${self.network_interface.0.access_config.0.nat_ip},' ansible-playbook.yml -v"
  }

  # Stop machine
  provisioner "local-exec" {
    command = "gcloud compute instances stop ${self.name} --project ${var.project} --zone ${var.zone}"
  }
}

resource "google_compute_image" "image" {
  count = var.source_machine_image == "" ? 1 : 0
  project = var.project
  name    = google_compute_instance.vm.0.name

  source_disk = "projects/${var.project}/zones/${var.zone}/disks/${google_compute_instance.vm.0.name}"
}
