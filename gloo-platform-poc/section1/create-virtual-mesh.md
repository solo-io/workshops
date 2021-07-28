# Create virtual mesh

A Gloo Mesh `VirtualMesh` allows us to group meshes and treat them as a single configuration domain from a multi-cluster configuration standpoint. We will the two meshes created in earlier steps into a single `VirtualMesh`

## Prerequisites

Please see the assumptions we make about the environment [for this section](./README.md).

## Creating a VirtualMesh

```bash
kubectl --context $MGMT_CONTEXT apply -f resources/gloo-mesh/virtual-mesh.yaml
```

## Validate the virtual mesh was created

```bash
. ./scripts/check-virtualmesh.sh
```
