for i in {'07','06','05','04','03','02','01'}
do
  echo "Cleaning up resources LAB$i"
  pushd ./$i
  ./cleanup.sh
  popd
done

# delete all istio
istioctl x uninstall -y --purge
kubectl delete ns istio-system
