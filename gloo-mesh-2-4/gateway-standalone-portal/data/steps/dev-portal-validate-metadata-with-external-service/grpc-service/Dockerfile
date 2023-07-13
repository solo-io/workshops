# builder image
FROM golang as builder
WORKDIR /build
ADD go* /build/
RUN go mod download
COPY ./pkg /build/pkg
ADD *.go /build/
RUN CGO_ENABLED=0 GOOS=linux go build -a --ldflags '-extldflags "-static"' -tags "netgo" -installsuffix netgo -o server .

# generate clean, final image for end users
FROM scratch
COPY --from=builder /build/server .
ENTRYPOINT [ "./server" ]

#podman machine start
#podman build -t gcr.io/field-engineering-eu/jesus-passthrough-grpc-service:0.2.4 .
#podman push gcr.io/field-engineering-eu/jesus-passthrough-grpc-service:0.2.4
#podman machine stop