package v3

import (
	"context"
	"encoding/json"
	"log"
	"strings"

	envoy_api_v3_core "github.com/envoyproxy/go-control-plane/envoy/config/core/v3"
	"github.com/golang/protobuf/ptypes/wrappers"

	envoy_service_auth_v3 "github.com/envoyproxy/go-control-plane/envoy/service/auth/v3"
	"google.golang.org/genproto/googleapis/rpc/code"
	"google.golang.org/genproto/googleapis/rpc/status"

	"github.com/graphql-go/graphql/language/ast"
	"github.com/graphql-go/graphql/language/parser"
	"github.com/graphql-go/graphql/language/source"

	structpb "github.com/golang/protobuf/ptypes/struct"
)

type server struct {
}

type GraphQLRequest struct {
	Query string `json:"query"`
}

var _ envoy_service_auth_v3.AuthorizationServer = &server{}

// New creates a new authorization server.
func New() envoy_service_auth_v3.AuthorizationServer {
	return &server{}
}

func toCamelCase(s string) string {
	if s == "" {
		return ""
	}
	// Convert first character to uppercase
	firstChar := strings.ToUpper(string(s[0]))
	// Convert the rest to lowercase
	rest := strings.ToLower(s[1:])
	return firstChar + rest
}

// Check implements authorization's Check interface which performs authorization check based on the
// attributes associated with the incoming request.
func (s *server) Check(
	ctx context.Context,
	req *envoy_service_auth_v3.CheckRequest) (*envoy_service_auth_v3.CheckResponse, error) {
	var request GraphQLRequest

	err := json.Unmarshal([]byte(req.Attributes.Request.Http.Body), &request)
	if err != nil {
		return &envoy_service_auth_v3.CheckResponse{
			Status: &status.Status{
				Code: int32(code.Code_OK),
			},
		}, nil
	}

	src := source.NewSource(&source.Source{
		Body: []byte(request.Query),
		Name: "GraphQL request",
	})

	doc, err := parser.Parse(parser.ParseParams{
		Source: src,
	})

	if err != nil {
		return &envoy_service_auth_v3.CheckResponse{
			Status: &status.Status{
				Code: int32(code.Code_OK),
			},
		}, nil
	}

	var headers []*envoy_api_v3_core.HeaderValueOption
	fieldHeaders := map[string]*structpb.Value{}

	for _, definition := range doc.Definitions {
		if operation, ok := definition.(*ast.OperationDefinition); ok {
			for _, selection := range operation.SelectionSet.Selections {
				if field, ok := selection.(*ast.Field); ok {
					header := &envoy_api_v3_core.HeaderValueOption{
						Append: &wrappers.BoolValue{Value: false},
						Header: &envoy_api_v3_core.HeaderValue{
							Key:   "X-Graphql-Query-Mutation-" + toCamelCase(field.Name.Value),
							Value: "true",
						},
					}
					log.Println("Adding header " + "X-Graphql-Query-Mutation-" + toCamelCase(field.Name.Value))
					headers = append(headers, header)
					fieldHeaders["X-Graphql-Query-Mutation-"+toCamelCase(field.Name.Value)] = &structpb.Value{
						Kind: &structpb.Value_StringValue{
							StringValue: "true",
						},
					}
				}
			}
		}
	}

	newState := &structpb.Struct{
		Fields: fieldHeaders,
	}

	return &envoy_service_auth_v3.CheckResponse{
		HttpResponse: &envoy_service_auth_v3.CheckResponse_OkResponse{
			OkResponse: &envoy_service_auth_v3.OkHttpResponse{
				Headers: headers,
			},
		},
		Status: &status.Status{
			Code: int32(code.Code_OK),
		},
		DynamicMetadata: &structpb.Struct{
			Fields: map[string]*structpb.Value{
				soloPassThroughAuthMetadataKey: {
					Kind: &structpb.Value_StructValue{
						StructValue: newState,
					},
				},
			},
		},
	}, nil
}
