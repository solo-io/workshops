# Build gloo edge golden image
```
cd packer/instruqt-gloo-edge
packer build -force .
```

After the building process, you will get the name of the image in the log:
```
googlecompute.k3s: A disk image was created: workshop-instruqt-gloo-edge-v1-19-15-k3s2-20211108
```
# Build gloo mesh golden image

cd packer/instruqt-gloo-mesh
packer build -force .

After the building process, you will get the name of the image in the log:
```
googlecompute.k3s: A disk image was created: workshop-instruqt-gloo-mesh-v1-19-15-k3s2-20211108
```