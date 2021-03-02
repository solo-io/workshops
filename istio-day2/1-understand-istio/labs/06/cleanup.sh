kubectl delete -n istioinaction envoyfilter web-api-access-log
kubectl delete -n istioinaction authorizationpolicy audit-web-api-authpolicy
kubectl delete -n istioinaction peerauthentication default
kubectl delete -n istioinaction destinationrule purchase-history-dr
kubectl delete -n istioinaction peerauthentication purchase-history-strict