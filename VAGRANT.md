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

## Destroy

Run the following command to destroy the VM

```
vagrand destroy -f
```