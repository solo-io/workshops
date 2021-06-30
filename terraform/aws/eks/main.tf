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
      export KUBECONFIG=${path.root}/output/${module.eks[count.index].cluster_name}/kubeconfig-${module.eks[count.index].cluster_name} \
      && kubectl apply -f ${path.module}/templates/eks-admin.yaml \
      && TOKEN=$(kubectl describe -n kube-system secrets "$(kubectl describe -n kube-system serviceaccount eks-admin | grep -i Tokens | awk '{print $2}')" | grep token: | awk '{print $2}') \
      && kubectl config set-credentials workshop --token=$TOKEN \
      && kubectl config set-context workshop --cluster=${module.eks[count.index].cluster_name} --user=workshop \
      && kubectl config use-context workshop
    COMMAND
  }

  triggers = {
    kubeconfig_rendered = module.eks[count.index].kubeconfig
  }
}