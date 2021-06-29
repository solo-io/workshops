source env.sh

until [ $(kubectl --context $MGMT_CONTEXT -n gloo-mesh get virtualmesh your-virtual-mesh -o jsonpath="{.status.state}"| grep ACCEPTED -c) -eq 1 ]; do
  echo "Waiting for VirtualMesh to converge..."
  sleep 1
done

echo "VirtualMesh has converged!"
sleep 5s

