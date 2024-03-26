package main

import (
	"flag"
	"fmt"
	"log"
	"net"
	"time"

	"google.golang.org/grpc/keepalive"

	envoy_service_auth_v3 "github.com/envoyproxy/go-control-plane/envoy/service/auth/v3"
	"google.golang.org/grpc"

	authv3 "github.com/envoyproxy/envoy/examples/ext_authz/auth/grpc-service/pkg/auth/v3"
)

func main() {
	port := flag.Int("port New", 9001, "gRPC port New")

	flag.Parse()

	lis, err := net.Listen("tcp", fmt.Sprintf(":%d", *port))
	if err != nil {
		log.Fatalf("failed to listen to %d: %v", *port, err)
	}

	opts := []grpc.ServerOption{
		grpc.KeepaliveParams(keepalive.ServerParameters{
			MaxConnectionAge: 1 * time.Second,
		}),
	}

	gs := grpc.NewServer(opts...)

	//envoy_service_auth_v3.RegisterAuthorizationServer(gs1, authv3.New())
	//envoy_service_auth_v3.RegisterAuthorizationServer(gs2, authv3.NewAuthServerWithRequiredJwtToken())
	//envoy_service_auth_v3.RegisterAuthorizationServer(gs3, authv3.NewAuthServerWithNewState())
	envoy_service_auth_v3.RegisterAuthorizationServer(gs, authv3.NewGeoIp())

	log.Printf("starting (geoip)gRPC server on: %d\n", *port)
	gs.Serve(lis)
	//go gs.Serve(lis2)
}
