apiVersion: v1
kind: ServiceAccount
metadata:
  name: undefined
  namespace: httpbin
---
apiVersion: v1
kind: Service
metadata:
  name: undefined
  namespace: httpbin
  labels:
    app: undefined
    service: undefined
spec:
  ports:
  - name: http
    port: 8000
    targetPort: 80
  selector:
    app: undefined
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: undefined
  namespace: httpbin
spec:
  replicas: 1
  selector:
    matchLabels:
      app: undefined
      version: v1
  template:
    metadata:
      labels:
        app: undefined
        version: v1
    spec:
      serviceAccountName: undefined
      containers:
      - image: docker.io/kennethreitz/httpbin
        imagePullPolicy: IfNotPresent
        name: undefined
        ports:
        - containerPort: 80