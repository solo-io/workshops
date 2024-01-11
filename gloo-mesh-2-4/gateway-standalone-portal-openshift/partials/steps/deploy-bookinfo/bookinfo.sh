kubectl --context undefined create ns bookinfo-frontends
kubectl --context undefined create ns bookinfo-backends
# Deploy the frontend bookinfo service in the bookinfo-frontends namespace
kubectl --context undefined -n bookinfo-frontends apply -f data/steps/deploy-bookinfo/productpage-v1.yaml
# Deploy the backend bookinfo services in the bookinfo-backends namespace for all versions
kubectl --context undefined -n bookinfo-backends apply \
  -f data/steps/deploy-bookinfo/details-v1.yaml \
  -f data/steps/deploy-bookinfo/ratings-v1.yaml \
  -f data/steps/deploy-bookinfo/reviews-v1-v2.yaml \
  -f data/steps/deploy-bookinfo/reviews-v3.yaml
# Update the reviews service to display where it is coming from
kubectl --context undefined -n bookinfo-backends set env deploy/reviews-v1 CLUSTER_NAME=undefined
kubectl --context undefined -n bookinfo-backends set env deploy/reviews-v2 CLUSTER_NAME=undefined