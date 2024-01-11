module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "v3.1.0"
  count   = var.num_instances

  name = "${terraform.workspace}-${var.prefix}-${count.index + 1}"
  cidr = "10.0.0.0/16"

  azs            = var.azs_controlplane
  public_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]

  tags = merge(
    {
      "kubernetes.io/cluster/${terraform.workspace}-${var.prefix}-${count.index + 1}" = "shared",
      "kubernetes.io/role/elb" = "1"
    },
    local.common_tags,
  )
}

data "aws_subnet_ids" "nodes" {
  count  = var.num_instances
  vpc_id = module.vpc[count.index].vpc_id
  filter {
    name   = "tag:Name"
    values = [for str in var.azs_workers : format("*%s", str)]
  }
}

resource "null_resource" "output" {
  count = var.num_instances

  provisioner "local-exec" {
    command = "mkdir -p ${path.root}/output/${terraform.workspace}-${var.prefix}-${count.index + 1}"
  }

  triggers = {
    cluster_name        = module.eks[count.index].cluster_name
    kubeconfig_rendered = module.eks[count.index].kubeconfig
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
  # node_ami_lookup    = "solo-eks-node-${var.eks_version}*"
  # node_ami_id    = "ami-0484a03969565977f"
  # node_user_data = "amazon-linux-extras install -y kernel-5.10"
  eks_version = var.eks_version
}

resource "null_resource" "eks-admin" {
  count = var.num_instances

  provisioner "local-exec" {
    command = <<COMMAND
      cp ${path.root}/output/${module.eks[count.index].cluster_name}/kubeconfig-${module.eks[count.index].cluster_name} ${path.root}/output/${module.eks[count.index].cluster_name}/full-kubeconfig \
      && export KUBECONFIG=${path.root}/output/${module.eks[count.index].cluster_name}/full-kubeconfig \
      && kubectl apply -f ${path.module}/templates/eks-admin.yaml \
      && TOKEN=$(kubectl describe -n kube-system secrets "$(kubectl describe -n kube-system serviceaccount eks-admin | grep -i Tokens | awk '{print $2}')" | grep token: | awk '{print $2}') \
      && kubectl config unset users.${module.eks[count.index].cluster_name} \
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

  provisioner "local-exec" {
    when       = destroy
    on_failure = continue
    # Delete all pv,pvc, and non essential services
    command = <<COMMAND
      export KUBECONFIG=${path.root}/output/${self.triggers.cluster_name}/kubeconfig-${self.triggers.cluster_name} \
      && kubectl delete pvc -A --all --timeout=5m\
      && kubectl delete pv -A --all --timeout=5m\
      && kubectl delete svc -A --selector='!provider,!kubernetes.io/cluster-service' --timeout=5m
    COMMAND
  }

  provisioner "local-exec" {
    when       = destroy
    on_failure = continue
    command    = <<COMMAND
      aws ec2 describe-security-groups --filters Name=tag:aws:eks:cluster-name,Values=${self.triggers.cluster_name} --query "SecurityGroups[*].GroupId" | jq -r '.[]' | xargs -L1 aws ec2 delete-security-group --group-id
    COMMAND
  }

  triggers = {
    cluster_name        = module.eks[count.index].cluster_name
    kubeconfig_rendered = module.eks[count.index].kubeconfig
  }
}

data "aws_eks_cluster" "cp" {
  count      = var.aws_lb_controller > 0 ? var.num_instances : 0
  name       = module.eks[count.index].cluster_name
  depends_on = [module.eks]
}

resource "aws_iam_openid_connect_provider" "oidc" {
  count           = var.aws_lb_controller > 0 ? var.num_instances : 0
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["9e99a48a9960b14926bb7f3b02e22da2b0ab7280"]
  url             = data.aws_eks_cluster.cp[count.index].identity.0.oidc.0.issuer
}

/*
module "lb-controller" {
  count        = var.aws_lb_controller > 0 ? var.num_instances : 0
  source       = "Young-ook/eks/aws//modules/lb-controller"
  oidc = {
    arn = aws_iam_openid_connect_provider.oidc[count.index].arn
    url = replace(aws_iam_openid_connect_provider.oidc[count.index].url, "https://", "")
  }
  tags = { env = "test" }
}
*/

module "vm-replica" {
  source = "../../gce/vm-replica"
  count  = ceil(var.num_instances / var.vm_merge_kubeconfig) > 0 ? 1 : 0

  prefix               = "${var.prefix}-eks"
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
