apiVersion: apps/v1
kind: Deployment
metadata:
  name: extauth-grpcservice
  namespace: gloo-mesh-addons
spec:
  selector:
    matchLabels:
      app: grpc-extauth
  replicas: 1
  template:
    metadata:
      labels:
        app: grpc-extauth
    spec:
      containers:
      - name: grpc-extauth
        image: gcr.io/field-engineering-eu/jesus-passthrough-grpc-service:0.2.6
        imagePullPolicy: Always
        ports:
        - containerPort: 9001
---
apiVersion: v1
kind: Service
metadata:
  name: example-grpc-auth-service
  namespace: gloo-mesh-addons
  labels:
      app: grpc-extauth
spec:
  ports:
  - port: 9001
    protocol: TCP
  selector:
      app: grpc-extauth