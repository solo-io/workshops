# Troubleshooting

## I can't install terraform v0.15.4+

In this case, the recommended solution is a TF version manager that will in turn allow you to install more recent versions of tf than brew will allow on MacOS.

In addition, you will have the possibility of having several versions of TF at the same time (only 1 active)

```
install: https://github.com/tfutils/tfenv
tfenv install 0.15.4
```

## Error 403: user does not have serviceusage.services.use access to the Google Cloud project

Try to force auth
```
gcloud auth login
```

If that does not work, put you creadentials in JSON format in an environment variable as detailed in this url:

```
https://cloud.google.com/docs/authentication/production#passing_variable

export GOOGLE_CREDENTIALS="/home/user/Downloads/service-account-file.json"
```

If that is not enough, modify file version.tf to add the path to the credentials file, as explained:
```
https://www.terraform.io/docs/language/settings/backends/gcs.html#configuration-variables
```

## Trials licenses are not being exported to the final VMs

All solo.io enterprise products require a license key.  If you'd like to preset limited-term keys on the student Virtual Machines, then set the `LICENSE_KEY` and `GLOO_MESH_LICENSE_KEY` environment variables on your workstation before running the `terraform` command.

```
export LICENSE_KEY=VeryLongKeyString
export GLOO_MESH_LICENSE_KEY=AnotherVeryLongKeyString
```

## Create/Destroy only one environment

Go to the terraform directory:

```
cd terraform
```

Run the following command to destroy one enviroment:

```
terraform destroy -target=module.vm-replica[\"myname\"]
```

Run the following command to create one enviroment:

```
terraform apply -target=module.vm-replica[\"myname\"]
```

# Terraform fails, server unreachable

```
TASK [Gathering Facts] *************************
fatal: [35.232.102.15]: UNREACHABLE! => {"changed": false, "msg": "Failed to connect to the host via ssh: solo@35.232.102.15: Permission denied (publickey).", "unreachable": true}
```

Remove the entry from your known_hosts:
```
ssh-keygen -R 35.232.102.15
```

Check that you have the lab ssh_key added
```
ssh-add -L
```
If not, add it to the agent (the file can be found in shared drive)
```
ssh-add ~/.ssh/rsa_workshop
```

Check the permissions of the private key, if they are too open it won't be accepted. chmod 400 suggested.
```
ls -la ~/.ssh
```

# Private repos can't be downloaded
Private repos are downloaded using creadentials found in your local ssh agent. This is done to avoid embedding credentials in the final VMs

Check that you have the gitlab ssh_key added
```
ssh-add -L
```
If not, add it to the agent (the file can be found in shared drive)
```
ssh-add ~/.ssh/rsa_solouser_github
```

# Terraform apply error 'resource not found' 
There are strong dependencies among the resources created by terraform, and sometimes the child can't get the parent ready before the timeout.

Just run terraform apply again, with the same parameters, and terraform will resume the building
```
terraform apply
```

# Terraform apply failed
Run the same command again, terraform will complete the creation

# Terraform says it is locked
This can happen when a running apply is unexepctely closed, if you are sure there is not terraform process running
```
terraform force-unlock <lockid>
```

# Terraform is very slow
For a large number of resources (example 150 eks cluster => 4900 resources)

Increase the default level of parallelism (10) to a higher number. Be aware that too high numbers can cause rate-limit in cloud api and high cpu usage.
```
terraform apply -parallelism=150
```

Another, maybe better, alternative is to use different workspaces to build the same object in different namespaces.
These 3 commands can run in parallel, and every terraform process will deal with a portion of the final setup
```
TF_WORKSPACE=wkr-eks1 time terraform apply -parallelism=51 -auto-approve
TF_WORKSPACE=wkr-eks2 time terraform apply -parallelism=51 -auto-approve
TF_WORKSPACE=wkr-eks3 time terraform apply -parallelism=51 -auto-approve
```

After all commands are successful (you may need to retry some of them, as TF is not great handling large graphs of dependencies), you can see the outputs
```
TF_WORKSPACE=wkr-eks1 time terraform output eks_cluster_vm
TF_WORKSPACE=wkr-eks2 time terraform output eks_cluster_vm
TF_WORKSPACE=wkr-eks3 time terraform output eks_cluster_vm
```

And finally destroy them
```
TF_WORKSPACE=wkr-eks1 time terraform destroy -parallelism=51 -auto-approve -refresh=false
TF_WORKSPACE=wkr-eks2 time terraform destroy -parallelism=51 -auto-approve -refresh=false
TF_WORKSPACE=wkr-eks3 time terraform destroy -parallelism=51 -auto-approve -refresh=false
```

# Terraform says the maximum number of resources are created
```
https://eu-west-1.console.aws.amazon.com/servicequotas
https://console.cloud.google.com/iam-admin/quotas?project=solo-test-236622
```

# Terraform is not working
Make sure you have credentials in your system

```
# GCP
# https://registry.terraform.io/providers/hashicorp/google/latest/docs/guides/getting_started#configuring-the-provider
gcloud auth application-default login

# AWS
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs#authentication
aws configure
````

# Terraform is creating my resources in an undesired region/zone
Make sure you have specified your preferences in file configuration.auto.tfvars

```
# GCP
project = "solo-test-236622"
region  = "europe-west4"
zone    = "europe-west4-a"

# AWS
default_region = "eu-west-1"
````

# VM provisioning fails with Ansible github single_branch error

If you see an error in your Ansible output like this...
```
TASK [repo : Clone of master branch] *******************************************
fatal: [34.91.88.120]: FAILED! => {"changed": false, "msg": "Unsupported parameters for (git) module:
single_branch 
Supported parameters include: accept_hostkey, archive, archive_prefix, bare, clone, depth,
dest, executable, force, gpg_whitelist, key_file, recursive, reference, refspec, remote, repo,
separate_git_dir, ssh_opts, track_submodules, umask, update, verify_commit, version"}
```
...then check your version of Ansible. Versions older than 2.11 do not support the `single_branch` option. Upgrade your workstation to Ansible 2.11 or higher.
