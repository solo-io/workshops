K3S_VERSION ?= latest

build: check-variables
	packer build -var 'k3s_version=${K3S_VERSION}' k3s.pkr.hcl
