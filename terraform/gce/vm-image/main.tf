resource "google_compute_instance" "vm" {
  project      = var.project
  name         = "${var.prefix}-source-image"
  machine_type = var.machine_type
  zone         = var.zone

  tags = [var.prefix]

  boot_disk {
    initialize_params {
      image = var.vm_image
      size  = "100"
    }
  }

  // Local SSD disk
  scratch_disk {
    interface = "SCSI"
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

resource "google_compute_machine_image" "image" {
  provider        = google-beta
  project         = var.project
  name            = "${var.prefix}-source-image"
  source_instance = google_compute_instance.vm.self_link

  provisioner "local-exec" {
    command = "gcloud beta compute instances suspend ${self.name} --project ${var.project} --zone ${var.zone} --discard-local-ssd"
  }
}