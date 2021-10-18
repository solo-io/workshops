// Run with packer init workshop.pkr.hcl + packer build workshop.pkr.hcl

packer {
  required_plugins {
    googlecompute = {
      version = ">= 0.0.1"
      source = "github.com/hashicorp/googlecompute"
    }
  }
}

source "googlecompute" "workshop" {
  project_id   = "solo-test-236622"
  //region       = "europe-west1"
  //zone         = "europe-west1-d"
  region       = "asia-northeast1"
  zone         = "asia-northeast1-c"
  //region       = "us-central1"
  //zone         = "us-central1-a"

  image_storage_locations = [ "asia" ]
  image_family = "workshop-generic"
  image_name   = regex_replace("workshop-${ uuidv4() }", "[^a-zA-Z0-9_-]", "-")
  image_labels = {
      builder = "packer"
  }
      
  metadata = {
    enable-oslogin = "FALSE"
  }

  source_image = "ubuntu-2004-focal-v20210927"
  machine_type = "n1-standard-8"
  disk_size    = 20

  ssh_username = "solo"

  tags = ["packer"]
}

build {
  sources = ["source.googlecompute.workshop"]

  provisioner "ansible" {
    playbook_file = "./ansible-playbook.yml"
    extra_arguments = [ "-e", "reboot_vm_machine=no" ]
  }
}


