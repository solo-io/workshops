# Gloo Mesh workshop (local)

## Prerequisites

Install VirtualBox.

Install Vagrant.

Install Ansible.

## Deploy

Go to the terraform directory:

```
cd terraform
```

Run the following command to create the ansible `hosts` file:

```
cat > ./hosts <<EOF
[hosts]
vagrant ansible_host=127.0.0.1 ansible_port=2222 ansible_python_interpreter=/usr/bin/python3 ansible_user=vagrant ansible_ssh_private_key_file=$(pwd)/.vagrant/machines/default/virtualbox/private_key
EOF
```

Run the following command to deploy the Virtual Machine:

```
vagrant up
```

The ansible script will be automatically executed.

When it's done, Guacamole is available at http://localhost:8888/guacamole

You can also access the shell by running `vagrant ssh`. In this case, don't forget to switch to the `solo` user.

## Access Docker from your laptop

Run the following command on your laptop to configure the Docker CLI to use the Docker Engine running in the VM:

```
ssh-keyscan -p 2222 127.0.0.1 >> $HOME/.ssh/known_hosts
ssh-add $(pwd)/.vagrant/machines/default/virtualbox/private_key
export DOCKER_HOST="ssh://vagrant@127.0.0.1:2222"
vagrant ssh -c "sudo usermod -aG docker vagrant"
```

## Access Kubernetes from your laptop

If you deploy a Kubernetes cluster with KinD from your laptop, you won't be able to access it because the kubeconfig is referencing the port of the VM.

To map the same port on you laptop, run the following command:

```
./forward-port.sh <kind cluster name>
```

If you deployed it witk KinD from the VM and you want to access it from your laptop, you can run the following command to create the kubeconfig on your laptop:


```
kind export kubeconfig --name <kind cluster name>
```

Then, you stil need to map the port using the previous command.

To remove all the port mappings, you can run the following command:

```
pkill -f fNT
```

## Destroy

Run the following command to destroy the VM

```
vagrant destroy -f
```
