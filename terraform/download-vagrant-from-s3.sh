#!/bin/sh
mkdir -p vagrant-workshop
vagrant_version=$(cat vagrant-image-stable.txt)
aws s3 cp s3://artifacts.solo.io/vagrant-images/workshop-generic-${vagrant_version}-vagrant.box vagrant-workshop/package.box
aws s3 cp s3://artifacts.solo.io/vagrant-images/workshop-generic-${vagrant_version}-vagrant.Vagrantfile vagrant-workshop/Vagrantfile
vagrant box add --force packer_solo_image vagrant-workshop/package.box
