module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "v3.1.0"
  count   = var.num_instances

  name = "${terraform.workspace}-${var.prefix}-${count.index + 1}"
  cidr = "10.0.0.0/16"

  azs            = var.azs_controlplane
  public_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]

  tags = {
    "kubernetes.io/cluster/${terraform.workspace}-${var.prefix}-${count.index + 1}" = "shared"
  }
}

data "aws_subnet_ids" "nodes" {
  count  = var.num_instances
  vpc_id = module.vpc[count.index].vpc_id
  filter {
    name   = "tag:Name"
    values = [for str in var.azs_workers : format("*%s", str)]
  }
}

module "eks" {
  source  = "howdio/eks/aws"
  version = "v2.0.2"
  count   = var.num_instances

  name               = "${terraform.workspace}-${var.prefix}-${count.index + 1}"
  vpc_id             = module.vpc[count.index].vpc_id
  cluster_subnet_ids = flatten([module.vpc[count.index].private_subnets, module.vpc[count.index].public_subnets])
  node_subnet_ids    = data.aws_subnet_ids.nodes[count.index].ids
  node_instance_type = var.node_instance_type
  node_ami_lookup    = "amazon-eks-node-${var.eks_version}*"
  eks_version        = var.eks_version
}

resource "null_resource" "eks-admin" {
  count = var.num_instances

  provisioner "local-exec" {
    command = <<COMMAND
      cp ${path.root}/output/${module.eks[count.index].cluster_name}/kubeconfig-${module.eks[count.index].cluster_name} ${path.root}/output/${module.eks[count.index].cluster_name}/full-kubeconfig \
      && export KUBECONFIG=${path.root}/output/${module.eks[count.index].cluster_name}/full-kubeconfig \
      && kubectl apply -f ${path.module}/templates/eks-admin.yaml \
      && TOKEN=$(kubectl describe -n kube-system secrets "$(kubectl describe -n kube-system serviceaccount eks-admin | grep -i Tokens | awk '{print $2}')" | grep token: | awk '{print $2}') \
      && kubectl config delete-user ${module.eks[count.index].cluster_name} || true \
      && kubectl config set-credentials ${module.eks[count.index].cluster_name} --token=$TOKEN \
      && kubectl config set-context ${module.eks[count.index].cluster_name} --cluster=${module.eks[count.index].cluster_name} --user=${module.eks[count.index].cluster_name} \
      && kubectl config use-context ${module.eks[count.index].cluster_name} \
      && kubectl config view --flatten --minify > ${path.root}/output/${module.eks[count.index].cluster_name}/guest-kubeconfig
    COMMAND
  }

  provisioner "local-exec" {
    when       = destroy
    on_failure = continue
    command    = <<COMMAND
      rm ${path.root}/output/${self.triggers.cluster_name}/*-kubeconfig
    COMMAND
  }

  triggers = {
    cluster_name        = module.eks[count.index].cluster_name
    kubeconfig_rendered = module.eks[count.index].kubeconfig
  }
}

module "vm-replica" {
  source = "../../gce/vm-replica"
  count  = ceil(var.num_instances / var.vm_merge_kubeconfig) > 0 ? 1 : 0

  prefix               = var.prefix
  project              = var.vm_project
  machine_type         = var.vm_machine_type
  zone                 = var.vm_zone
  num_instances        = ceil(var.num_instances / var.vm_merge_kubeconfig)
  source_machine_image = var.vm_source_machine_image
}

resource "null_resource" "inject-kubeconfig" {
  count = ceil(var.num_instances / var.vm_merge_kubeconfig) > 0 ? ceil(var.num_instances / var.vm_merge_kubeconfig) : 0

  connection {
    host    = module.vm-replica[0].gce_public_ip[count.index]
    user    = "solo"
    timeout = "30s"
  }

  provisioner "file" {
    source      = "${path.root}/output/${module.eks[(var.vm_merge_kubeconfig * count.index) + 0].cluster_name}/guest-kubeconfig"
    destination = "/tmp/mgmt-kubeconfig"
  }
  provisioner "file" {
    source      = "${path.root}/output/${module.eks[(var.vm_merge_kubeconfig * count.index) + 1].cluster_name}/guest-kubeconfig"
    destination = "/tmp/cluster1-kubeconfig"
  }
  provisioner "file" {
    source      = "${path.root}/output/${module.eks[(var.vm_merge_kubeconfig * count.index) + 2].cluster_name}/guest-kubeconfig"
    destination = "/tmp/cluster2-kubeconfig"
  }
  provisioner "remote-exec" {
    # Bootstrap script called with public_ip of vm with 3 kubeconfigs
    inline = [
      "echo num_instances=${var.num_instances}, vm_merge_kubeconfig=${var.vm_merge_kubeconfig}, count.index=${count.index}",
      "mkdir -p $HOME/.kube",
      "KUBECONFIG=/tmp/mgmt-kubeconfig kubectl config rename-context ${module.eks[(var.vm_merge_kubeconfig * count.index) + 0].cluster_name} mgmt",
      "KUBECONFIG=/tmp/cluster1-kubeconfig kubectl config rename-context ${module.eks[(var.vm_merge_kubeconfig * count.index) + 1].cluster_name} cluster1",
      "KUBECONFIG=/tmp/cluster2-kubeconfig kubectl config rename-context ${module.eks[(var.vm_merge_kubeconfig * count.index) + 2].cluster_name} cluster2",
      "KUBECONFIG=/tmp/mgmt-kubeconfig:/tmp/cluster1-kubeconfig:/tmp/cluster2-kubeconfig kubectl config view --flatten > $HOME/.kube/config",
      "kubectl config get-contexts",
    ]
  }

  triggers = {
    replica_ip          = module.vm-replica[0].gce_public_ip[count.index]
    kubeconfig_rendered = module.eks[count.index].kubeconfig
    eks_admin_1         = null_resource.eks-admin[(var.vm_merge_kubeconfig * count.index) + 0].id
    eks_admin_2         = null_resource.eks-admin[(var.vm_merge_kubeconfig * count.index) + 1].id
    eks_admin_3         = null_resource.eks-admin[(var.vm_merge_kubeconfig * count.index) + 2].id
  }

  depends_on = [null_resource.eks-admin]
}