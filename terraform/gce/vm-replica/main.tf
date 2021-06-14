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

resource "google_compute_instance_from_machine_image" "tpl" {
  provider = google-beta
  count    = var.num_instances
  name     = "${terraform.workspace}-${var.prefix}-${count.index + 1}"
  zone     = var.zone

  source_machine_image = var.source_machine_image

  // Override fields from machine image
  project      = var.project
  machine_type = var.machine_type
  labels = {
    source_image = split("/", var.source_machine_image)[4]
  }

  # Wait until ip is available
  provisioner "local-exec" {
    command = "echo 'waiting for ip ${self.network_interface.0.access_config.0.nat_ip}' && until nc -z ${self.network_interface.0.access_config.0.nat_ip} 22; do sleep 1; done && sleep 10"
  }

  # Provision machine with ansible
  provisioner "local-exec" {
    command = "ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -u solo -i '${self.network_interface.0.access_config.0.nat_ip},' -e ansible_python_interpreter=/usr/bin/python3 -e reboot_vm=true ansible-playbook.yml -v"
  }
}