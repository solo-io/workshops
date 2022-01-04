variable "eks_version" {
  type    = string
  default = "1.20"
}

data "amazon-ami" "src-ami" {
  filters = {
    virtualization-type = "hvm"
    name                = "amazon-eks-node-${var.eks_version}*"
    root-device-type    = "ebs"
  }
  owners = [
    "amazon"
  ]
  most_recent = true
  region      = "eu-west-1"
}

source "amazon-ebs" "solo-ami" {
  source_ami    = data.amazon-ami.src-ami.id
  instance_type = "t3.medium"
  ssh_username  = "ec2-user"
  ssh_pty       = true
  ssh_interface = ""
  ami_name      = "solo-eks-node-${var.eks_version}-{{timestamp}}"
  region        = "eu-west-1"
}

build {
  sources = [
    "source.amazon-ebs.solo-ami"
  ]
  provisioner "shell" {
    script = "kernel_upgrade.sh"
  }
}