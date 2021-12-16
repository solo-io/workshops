#!/bin/sh
cd packer/instruqt-gloo-mesh
packer init k3s.pkr.hcl
packer build -force -color=true -timestamp-ui -var 'k3s_version=v1.21.7+k3s1' -var 'gloo_version=1.2.2' -var 'istio_version=1.11.4' -var 'vcluster_version=v0.4.5' k3s.pkr.hcl
