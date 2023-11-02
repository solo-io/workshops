apiVersion: v1
data:
  my-rego.rego: |
    package test
    default allow = false
    allow {
        [header, payload, signature] = io.jwt.decode(input.state.jwt)
        endswith(payload["email"], "@solo.io")
    }
  .manifest: |
    {"roots": ["/"]}
kind: ConfigMap
metadata:
  name: bundle
  namespace: gloo-mesh-addons
---
apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    app: pap
  name: pap
  namespace: gloo-mesh-addons
spec:
  replicas: 1
  selector:
    matchLabels:
      app: pap
  template:
    metadata:
      labels:
        app: pap
    spec:
      initContainers:
      - name: build
        image: openpolicyagent/opa:0.57.1-debug
        workingDir: /bundle
        command: ["/bin/sh"]
        args:
          - -c
          - opa build /tmp/bundle/my-rego.rego /tmp/bundle/.manifest -o /tmp/static/bundle.tar.gz
        volumeMounts:
        - name: bundle
          mountPath: "/tmp/bundle"
        - name: static
          mountPath: "/tmp/static"
      containers:
      - image: nginx:1.25.3
        imagePullPolicy: Always
        name: nginx
        ports:
        - containerPort: 80
        volumeMounts:
        - mountPath: /usr/share/nginx/html
          name: static
      restartPolicy: Always
      volumes:
      - name: bundle
        configMap:
          name: bundle
      - name: static
        emptyDir: {}
---
apiVersion: v1
kind: Service
metadata:
  labels:
    app: pap
  name: pap
  namespace: gloo-mesh-addons
spec:
  ports:
  - port: 80
    protocol: TCP
    targetPort: 80
  selector:
    app: pap