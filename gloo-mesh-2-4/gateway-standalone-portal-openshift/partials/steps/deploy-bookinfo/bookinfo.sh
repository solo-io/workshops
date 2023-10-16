kubectl --context  create ns bookinfo-frontends
kubectl --context  create ns bookinfo-backends
# deploy the frontend bookinfo service in the bookinfo-frontends namespace
kubectl --context  -n bookinfo-frontends apply -f bookinfo.yaml -l 'account in (productpage)'
kubectl --context  -n bookinfo-frontends apply -f bookinfo.yaml -l 'app in (productpage)'
kubectl --context  -n bookinfo-backends apply -f bookinfo.yaml -l 'account in (reviews,ratings,details)'
# deploy the backend bookinfo services in the bookinfo-backends namespace for all versions
  kubectl --context  -n bookinfo-backends apply -f bookinfo.yaml -l 'app in (reviews,ratings,details)'
# Update the productpage deployment to set the environment variables to define where the backend services are running
kubectl --context  -n bookinfo-frontends set env deploy/productpage-v1 DETAILS_HOSTNAME=details.bookinfo-backends.svc.cluster.local
kubectl --context  -n bookinfo-frontends set env deploy/productpage-v1 REVIEWS_HOSTNAME=reviews.bookinfo-backends.svc.cluster.local
# Update the reviews service to display where it is coming from
kubectl --context  -n bookinfo-backends set env deploy/reviews-v1 CLUSTER_NAME=
kubectl --context  -n bookinfo-backends set env deploy/reviews-v2 CLUSTER_NAME=