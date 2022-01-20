packer {
  required_plugins {
    googlecompute = {
      version = ">= 0.0.1"
      source = "github.com/hashicorp/googlecompute"
    }
  }
}

variable "k3s_version" {
  type    = string
  default = "v1.23.1+k3s1"
}

source "googlecompute" "k3s" {
  project_id   = "solo-test-236622"
  region       = "us-central1"
  zone         = "us-central1-a"

  image_storage_locations = [ "us" ]
  image_family = "workshop-instruqt-ebpfworker"
  image_name   = regex_replace("workshop-instruqt-ebpfworker-k3s-${var.k3s_version}-${formatdate("YYYYMMDD", timestamp())}", "[^a-zA-Z0-9_-]", "-")
  image_labels = {
      builder = "packer"
  }
      
  metadata = {
    enable-oslogin = "FALSE"
  }

  source_image_family = "ubuntu-2104"

  machine_type = "n1-standard-8"
  disk_size    = 20

  ssh_username = "root"

  tags = ["packer"]
}

build {
    sources = ["source.googlecompute.k3s"]

    provisioner "file" {
        source      = "files/k3s-start.sh"
        destination = "/usr/local/bin/k3s-start.sh"
    }

    provisioner "shell" {
        inline = ["curl -sfL https://get.k3s.io | sh -"]
        environment_vars = [
            "INSTALL_K3S_VERSION=${ var.k3s_version }",
            "INSTALL_K3S_SKIP_START=true"
        ]
    }

      provisioner "file" {
        sources = [
            "files/k3s.service",
        ]
        destination = "/etc/systemd/system/"
    }
}
