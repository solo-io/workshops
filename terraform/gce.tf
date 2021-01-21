locals {
  ssh_file = "./lab.pub"
}

resource "google_compute_instance" "default" {
  count         = "2"
  name         = "ceposta-workshop-${count.index + 1}"
  machine_type = "n1-standard-8"
  zone         = "us-west1-a"

  tags = ["http-server", "https-server"]

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

  project = "solo-test-236622"

  metadata = {
    enable-oslogin = "FALSE"
    ssh-keys = "solo:${file(local.ssh_file)}"
  }
}

output "gce_public_ip" {
  value = "${google_compute_instance.default[*].network_interface.0.access_config.0.nat_ip}"  
}
