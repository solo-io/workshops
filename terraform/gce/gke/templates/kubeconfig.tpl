
apiVersion: v1
clusters:
- cluster:
    certificate-authority-data: ${cluster_ca_certificate}
    server: https://${endpoint}
  name: ${suffix}
contexts:
- context:
    cluster: ${suffix}
    user: ${suffix}
  name: ${suffix}
current-context: ${suffix}
kind: Config
preferences: {}
users:
- name: ${suffix}
  user:
    auth-provider:
      name: gcp