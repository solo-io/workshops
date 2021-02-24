# delete all istio
istioctl x uninstall -y --purge
kubectl delete ns istio-system

pushd ./01
./cleanup.sh
popd

pushd ./02
./cleanup.sh
popd

pushd ./03
./cleanup.sh
popd
