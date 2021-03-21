variable "prefix" {
  type = string
  default = "workshop"
}

locals {
  ssh_file = "./lab.pub"
}

resource "google_compute_instance" "default" {
  project = "solo-test-236622"
  count         = "2"
  name         = "${var.prefix}-${count.index + 1}"
  machine_type = "n1-standard-8"
  zone         = "europe-west1-b"

  tags = [var.prefix]

  boot_disk {
    initialize_params {
      image = "ubuntu-2004-focal-v20210211"
      size = "100"
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
    ssh-keys = "solo:${file(local.ssh_file)}"
  }
}

resource "google_compute_firewall" "default" {
  project = "solo-test-236622"
  name    = "${var.prefix}-firewall"
  network = "default"

  allow {
    protocol = "icmp"
  }

  allow {
    protocol = "tcp"
    ports    = ["80", "443", "22", "9900", "15443"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags = [var.prefix]
}

output "gce_public_ip" {
  value = "${google_compute_instance.default[*].network_interface.0.access_config.0.nat_ip}"  
}
