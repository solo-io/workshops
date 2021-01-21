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

Edit the `gce.tf` file to adapt it to your needs:

- the prefix of the `name` is `test-` by default, change it to your name, for example, to avoid conflicts with other workshops
- the `count` value should be updated to reflect the number of Virtual Machines you want to provision
- the `zone` value should be updated to use a GCP zone that is part of a region close to the people who will attend the workshop

Run the following command to deploy the Virtual Machines:

```
terraform apply -auto-approve
```

When the deployment is finished, you need to run the ansible script to deploy the prerequisites.

Load the `lab` ssh key:

---
**NOTE**  
If you don't already have the `lab` private key available locally, retrieve it from the shared Google Drive that contains other workshop resources.

---

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

All solo.io enterprise products require a license key.  If you'd like to preset limited-term keys on the student Virtual Machines, then set the `LICENSE_KEY` and `GLOO_MESH_LICENSE_KEY` and `PORTAL_LICENSE_KEY` environment variables on your workstation before running the `ansible-playbook` command.

```
export LICENSE_KEY=VeryLongKeyString
export GLOO_MESH_LICENSE_KEY=AnotherVeryLongKeyString
export PORTAL_LICENSE_KEY=AnotherVeryLongKeyString
```

Run the ansible playbook to apply all the prerequisites to the Virtual Machines.

```
export ANSIBLE_HOST_KEY_CHECKING=False
ansible-playbook -i ./hosts -f 30 ansible-playbook.yml
```

## Deliver

When you deliver the workshop, take the IP addresses from the `hosts` file and provide one to each student.

They simply need to access their Virtual Machine using `http://<ip address>/guacamole/`.

The user is `solo` and the password is `Workshop1#`

## Test

From any workshop directory (`gloo/federation`, for example), you can run the following command to extract all the instructions from the README.md and run them:

```
cat README.md | ../../md-to-bash.sh | bash
```

It allows you to test that all the instructions are still working after you modify the README.md

## Cleanup

Go to the terraform directory:

```
cd terraform
```

Run the following command to destroy all the VMs:

```
terraform destroy -force
```