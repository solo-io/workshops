# Service Mesh Hub workshop

## Prerequisites

Install terraform:

```
brew install terraform
```

Install ansible:

```
pip3 install ansible
```

## Deploy

Go to the terraform directory:

```
cd terraform
```

Run the following command is used to initialize the working directory:

```
terraform init
```

Edit the `gce.tf` file to change the `count` value to the number of Virtual Machines you want to provision.

Run the following command to deploy the Virtual Machines:

```
terraform apply -auto-approve
```

When the deployment is finished, you need to run the ansible script to deploy the prerequisites.

Load the lab ssh key:

```
ssh-add lab
```

Create the ansible `hosts` file from the terraform output:

```
echo "[hosts]" > hosts
terraform output -json | jq -r '.gce_public_ip.value[]' | while read ip; do echo $ip ansible_host=$ip ansible_user=solo >> hosts; done
```

Remove the SSH known hosts (optional, but recommended as Google Cloud reuses the same IP addresses quite often):

```
echo > $HOME/.ssh/known_hosts
```

Run the ansible playbook to apply all the prerequisites to the Virtual Machines

```
ansible-playbook -i ./hosts ansible-playbook.yml
```

## Deliver

When you deliver the workshop, take the IP addresses from the `hosts` file and provide one to each student.

They simply need to access their Virtual Machine using `http://<ip address>/guacamole/`.

The user is `solo` and the password is `Workshop1#`