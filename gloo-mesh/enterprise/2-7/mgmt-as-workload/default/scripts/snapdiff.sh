mv /tmp/current-output /tmp/previous-output 2>/dev/null
pod=$(kubectl --context ${MGMT} -n gloo-mesh get pods -l app=gloo-mesh-mgmt-server -o jsonpath='{.items[0].metadata.name}')
kubectl --context ${MGMT} -n gloo-mesh debug -q -i ${pod} --image=curlimages/curl -- curl -s http://localhost:9091/snapshots/output | jq '.translator | . as $root | ($root | keys[]) as $namespace | ($root[$namespace] | keys[]) as $parent | if $root[$namespace][$parent].Outputs then (($root[$namespace][$parent].Outputs | keys[]) as $object | ($object | split(",")) as $arr | {apiVersion: $arr[0], kind: ($arr[1] |split("=")[1])} + $root[$namespace][$parent].Outputs[$object][]) else empty end' | jq --slurp > /tmp/current-output
array1=$(cat /tmp/previous-output | jq -e '')
array2=$(cat /tmp/current-output | jq -e '')
jq -n --argjson array1 "$array1" --argjson array2 "$array2" '{"array1": $array1,"array2":$array2} | .array2-.array1' | docker run -i --rm mikefarah/yq -P '.'