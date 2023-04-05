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
  region       = "us-central1"
  zone         = "us-central1-a"

  image_storage_locations = [ "us" ]
  image_family = "workshop-generic"
  image_name   = "workshop-generic-v${formatdate("YYYYMMDD", timestamp())}"
  image_labels = {
      builder = "packer"
  }
      
  metadata = {
    enable-oslogin = "FALSE"
  }

  //source_image = "ubuntu-2004-focal-v20210927"
  source_image_family = "ubuntu-2004-lts"

  machine_type = "n1-standard-8"
  disk_size    = 20
  disk_type    = "pd-balanced"

  ssh_username = "solo"
  //temporary_key_pair_type = "ed25519"

  tags = ["packer"]
}

build {
  sources = ["source.googlecompute.workshop"]

  provisioner "ansible" {
    playbook_file = "./ansible-playbook.yml"
    use_proxy = false
    extra_arguments = [ "-e", "reboot_vm_machine=no", "-e", "provision=yes", "--scp-extra-args", "'-O'" ]
    ansible_ssh_extra_args = ["-oHostKeyAlgorithms=+ssh-rsa -oPubkeyAcceptedKeyTypes=+ssh-rsa -o IdentitiesOnly=yes"]
  }
}

// source "vagrant" "workshop" {
//   communicator = "ssh"
//   source_path = "ubuntu/focal64"
//   provider = "virtualbox"
//   skip_add = true
//   template = "Vagrantfile-tpl"
// }

// build {
//   sources = ["source.vagrant.workshop"]

//   provisioner "ansible" {
//     playbook_file = "./ansible-playbook.yml"
//     extra_arguments = [ "-e", "reboot_vm_machine=no", "-e", "vagrant=yes", "-e", "provision=yes" ]
//   }
//   post-processor "shell-local" {
//     inline = [
//       "aws s3 cp output-workshop/package.box s3://artifacts.solo.io/vagrant-images/workshop-generic-v${formatdate("YYYYMMDD", timestamp())}-vagrant.box",
//       "aws s3 cp output-workshop/Vagrantfile s3://artifacts.solo.io/vagrant-images/workshop-generic-v${formatdate("YYYYMMDD", timestamp())}-vagrant.Vagrantfile",
//     ]
//   }
// }