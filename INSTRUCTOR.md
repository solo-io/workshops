# Gloo Mesh workshop

## Prerequisites

Install terraform:

```
# Tested with terraform v0.15.4
brew install terraform
```

Install ansible:

```
# Tested with ansible v2.11.1 / python 3.9.5
pip3 install ansible
```

## Deploy

Go to the terraform directory:

```
cd terraform
```

Run the following command to initialize the working directory:

```
terraform init
```

Set your workspace:

```
terraform workspace list
terraform workspace select <workspace_name> || terraform workspace new <workspace_name>
```

Edit the `terraform.tfvars` file to adapt it to your needs:

- Add as many entries to `environment` as desired (or none). Every entry can be considered an isolated unit from the others
- Inside an `environment` all parameters are optional, and default values are defined in the same file
- Possible options:
```
  workshop1 = { # Prefix that will be shared in all objects
    project       = "solo-test-236622"
    # https://cloud.google.com/compute/docs/machine-types
    machine_type  = "n1-standard-8"
    # Zone where replicas will be created
    zone          = "europe-west4-a"
    # Replicas to deploy, in addition 1 'source-image' will be always created
    num_instances = 0
    # OS image https://cloud.google.com/compute/docs/images
    vm_image      = "ubuntu-2004-focal-v20210211"
  }

**NOTE**  
If you only want to create the source vm image and not any replica, just set num_instances = 0. You can re-run terraform again later with a number and the source image step will be skipped. The generation of the source image is a SLOW process.
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

Remove the SSH known hosts (optional, but recommended as Google Cloud reuses the same IP addresses quite often):

```
terraform output -json | jq -r '.gce_public_ip.value[]' | while read ip; do ssh-keygen -R $ip; done
```

All solo.io enterprise products require a license key.  If you'd like to preset limited-term keys on the student Virtual Machines, then set the `LICENSE_KEY` and `GLOO_MESH_LICENSE_KEY` and `PORTAL_LICENSE_KEY` environment variables on your workstation before running the `ansible-playbook` command.

```
export LICENSE_KEY=VeryLongKeyString
export GLOO_MESH_LICENSE_KEY=AnotherVeryLongKeyString
export PORTAL_LICENSE_KEY=AnotherVeryLongKeyString
```

Run the following command to deploy the Virtual Machines:

```
terraform apply -auto-approve
```

# Manual provisioning

Create the ansible `hosts` file from the terraform output:

```
export env_name = <myname> # PUT HERE YOUR ENV NAME IN terraform.tfvars
echo "[hosts]" > hosts
terraform output -json | jq -r ".gce_replicas_public_ip.value.${env_name}[]" | while read ip; do echo $ip ansible_host=$ip ansible_user=solo >> hosts; done
```

Run the ansible playbook to apply all the prerequisites to the Virtual Machines.

```
ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -i ./hosts -f 30 -e ansible_python_interpreter=/usr/bin/python3 -e reboot_vm=true ansible-playbook.yml
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

Run the following command to destroy all the replicas:

```
terraform destroy -target=module.vm-replica -force
```

Run the following command to destroy all the source images:

```
terraform destroy -target=module.vm-image -force
```

Run the following command to destroy all:

```
terraform destroy -force
```

## Additional reference

You can use emoji's in GitHub markdown to signal additional callouts such as:

* :information_source: - Info
* :memo: - Note
* :warning: - Warning
* :bulb: - hint
* :x: - Error
* :heavy_check_mark: - Correct
* :question: - Question
* :construction: - WIP
* :eyes: - Be careful

You can use GitBook [hints and callouts](https://docs.gitbook.com/editing-content/markdown#hints-and-callouts) with the following types:

* info
* success
* danger
* warning