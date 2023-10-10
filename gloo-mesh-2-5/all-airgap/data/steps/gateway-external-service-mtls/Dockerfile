# builder image
FROM golang as builder
WORKDIR /build
ADD *.go /build/
ADD go* /build/
#COPY ./client /build/client
RUN CGO_ENABLED=0 GOOS=linux go build -a --ldflags '-extldflags "-static"' -tags "netgo" -installsuffix netgo -o server .

# generate clean, final image for end users (use scratch instead of ubuntu for added security)
FROM ubuntu:22.04
COPY --from=builder /build/server .
ENTRYPOINT [ "./server" ]

# sudo docker build -t gcr.io/solo-test-236622/mtls-test:0.0.6 .
# sudo docker push gcr.io/solo-test-236622/mtls-test:0.0.6
# sudo docker build -t gcr.io/solo-test-236622/mtls-test:latest .
# sudo docker push gcr.io/solo-test-236622/mtls-test:latest