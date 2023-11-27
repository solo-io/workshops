package envoy.authz

import future.keywords.if

default allowed := false

default status_code := 403

default body := "Unauthorized Request"

result := {
	"dynamic_metadata": dynamic_metadata,
	"response_headers_to_add": response_headers_to_add,
	"allowed": allowed,
	"body": body,
	"headers": headers,
    "request_headers_to_remove": request_headers_to_remove,
}

data_key := data.Relations[key]

allowed if {
	data_key
}

api_product_id := input.check_request.attributes.metadata_context.filter_metadata["io.solo.gloo.apimanagement"].api_product_id

body := "Authorized: API Key is valid" if allowed

key := concat("/", [input.http_request.headers["api-key"], api_product_id])

headers["x-ext-auth-allow"] := "yes"

headers["x-validated-by"] := "security-checkpoint"

request_headers_to_remove := ["api-key"]

response_headers_to_add["x-response-header"] := "for-client-only"

response_headers_to_add["reject-reason"] := "unauthorized"

dynamic_metadata["rateLimit"] := data_key.metadata.rateLimit

dynamic_metadata["usagePlan"] := data_key.metadata.usagePlan
