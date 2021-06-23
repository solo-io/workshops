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