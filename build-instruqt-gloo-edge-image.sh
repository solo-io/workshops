#!/bin/sh
cd packer/instruqt-gloo-edge
packer init k3s.pkr.hcl
packer build -force -color=true -timestamp-ui -var 'k3s_version=v1.23.3+k3s1' -var 'glooee_version=1.10.3' -var 'gloo_version=1.10.1' k3s.pkr.hcl
