apiVersion: v1
kind: ServiceAccount
metadata:
  name: 
  namespace: httpbin
---
apiVersion: v1
kind: Service
metadata:
  name: 
  namespace: httpbin
  labels:
    app: 
    service: 
spec:
  ports:
  - name: http
    port: 8000
    targetPort: 80
  selector:
    app: 
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: 
  namespace: httpbin
spec:
  replicas: 1
  selector:
    matchLabels:
      app: 
      version: v1
  template:
    metadata:
      labels:
        app: 
        version: v1
    spec:
      serviceAccountName: 
      containers:
      - image: docker.io/kennethreitz/httpbin
        imagePullPolicy: IfNotPresent
        name: 
        ports:
        - containerPort: 80