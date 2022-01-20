#!/bin/bash -x

#create the registry
docker run \
    -d --restart=always -p 5000:5000 --name registry \
    registry:2

#use it to keep the k3s images
k3s_images=$(curl -sfL https://github.com/k3s-io/k3s/releases/download/${K3S_VERSION}/k3s-images.txt)
for i in $k3s_images
do
  docker pull $i
  shortname=$(echo -n $i| awk -F/ '{ print $NF }')
  name=$(echo -n $i| cut -d'/' -f 2-)
  docker tag $i "kubernetes:5000/${shortname}"
  docker push "kubernetes:5000/${shortname}"
  docker tag $i "kubernetes:5000/${name}"
  docker push "kubernetes:5000/${name}"
done
