resource "google_compute_instance" "vm" {
  project      = var.project
  count        = var.num_instances
  name         = "${var.source_machine_image}-${count.index + 1}"
  machine_type = var.machine_type
  zone         = var.zone

  tags = [var.prefix]

  labels = local.common_tags

  boot_disk {
    initialize_params {
      image = var.source_machine_image
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

  # Wait until ip is available
  provisioner "local-exec" {
    command = "echo 'waiting for ip ${self.network_interface.0.access_config.0.nat_ip}' && until nc -z ${self.network_interface.0.access_config.0.nat_ip} 22; do sleep 1; done && sleep 10"
  }

  # Provision machine with ansible
  provisioner "local-exec" {
    command = "ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -u solo -i '${self.network_interface.0.access_config.0.nat_ip},' ansible-playbook.yml -v"
  }

}

resource "google_compute_firewall" "default" {
  project = var.project
  name    = "${terraform.workspace}-${var.prefix}-firewall"
  network = "default"

  allow {
    protocol = "icmp"
  }

  allow {
    protocol = "tcp"
    ports    = ["80", "443", "22", "9900", "15443"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = [var.prefix]
}
