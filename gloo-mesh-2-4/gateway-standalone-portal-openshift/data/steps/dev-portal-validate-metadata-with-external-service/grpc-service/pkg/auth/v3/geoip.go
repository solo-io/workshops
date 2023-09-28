package v3

import (
	"context"
	"encoding/json"
	"io/ioutil"
	"log"
	"strings"
	"net/http"
	"reflect"
	"strconv"

	structpb "github.com/golang/protobuf/ptypes/struct"

	envoy_api_v3_core "github.com/envoyproxy/go-control-plane/envoy/config/core/v3"
	"github.com/golang/protobuf/ptypes/wrappers"

	envoy_service_auth_v3 "github.com/envoyproxy/go-control-plane/envoy/service/auth/v3"
	"google.golang.org/genproto/googleapis/rpc/code"
	"google.golang.org/genproto/googleapis/rpc/status"
)

type serverGeoIp struct {
}

type Geo struct {
	Status string `json:"status"`
	Country string `json:"country"`
	CountryCode string `json:"countryCode"`
	Region string `json:"region"`
	City string `json:"city"`
	Zip string `json:"zip"`
	Lat float64 `json:"lat"`
	Lon float64 `json:"lon"`
	Timezone string `json:"timezone"`
	Isp string `json:"isp"`
	Org string `json:"org"`
	As string `json:"as"`
	Query string `json:"query"`
}

var _ envoy_service_auth_v3.AuthorizationServer = &server{}

func NewGeoIp() envoy_service_auth_v3.AuthorizationServer {
	return &serverGeoIp{}
}

func StatusOK() (*envoy_service_auth_v3.CheckResponse, error) {
	return &envoy_service_auth_v3.CheckResponse{
		HttpResponse: &envoy_service_auth_v3.CheckResponse_OkResponse{
			OkResponse: &envoy_service_auth_v3.OkHttpResponse{},
		},
		Status: &status.Status{
			Code: int32(code.Code_OK),
		},
	}, nil
}

func (s *serverGeoIp) Check(
	ctx context.Context,
	req *envoy_service_auth_v3.CheckRequest) (*envoy_service_auth_v3.CheckResponse, error) {

	resp, err := http.Get("http://ip-api.com/json/" + strings.Split(req.Attributes.Request.Http.Headers["x-forwarded-for"],",")[0] + "?fields=status,country,countryCode,region,city,zip,lat,lon,timezone,isp,org,as,query")
	if err != nil {
		return StatusOK()
	} else {
		body, err := ioutil.ReadAll(resp.Body)
		if err != nil {
			return StatusOK()
		}

	    var geo Geo
		err = json.Unmarshal(body, &geo)
		if err != nil {
			return StatusOK()
		}

		v := reflect.ValueOf(geo)
    	typeOfS := v.Type()
    
		headers := []*envoy_api_v3_core.HeaderValueOption{}
		fieldHeaders := map[string]*structpb.Value{}
		for i := 0; i< v.NumField(); i++ {
			key := typeOfS.Field(i).Name
			value := ""
			if(key == "Lat" || key == "Lon") {
				value = strconv.FormatFloat(v.Field(i).Interface().(float64), 'f', 6, 64)
			} else {
				value = v.Field(i).Interface().(string)
			}
			headers = append(headers, &envoy_api_v3_core.HeaderValueOption{
				Append: &wrappers.BoolValue{Value: false},
				Header: &envoy_api_v3_core.HeaderValue{
					Key:   "geo-" + key,
					Value: value,
				},
			})
			fieldHeaders["geo-" + key] = &structpb.Value{
					Kind: &structpb.Value_StringValue{
						StringValue: value,
					},
			}
			
		}
		newState := &structpb.Struct{
			Fields: fieldHeaders,
		}
		//log.Println(req.Attributes.Request.Http.Headers)
		log.Println(fieldHeaders)
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
}