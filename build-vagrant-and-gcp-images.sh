#!/bin/sh
cd terraform
packer init workshop.pkr.hcl
packer build -force -color=true -timestamp-ui workshop.pkr.hcl