apiVersion: argoproj.io/v1alpha1
kind: AppProject
metadata:
  name: httpbin
  annotations:
    argocd.argoproj.io/sync-wave: "-1"
  finalizers:
  - resources-finalizer.argocd.argoproj.io
spec:
  sourceRepos:
  - '*'
  destinations:
  - namespace: '*'
    server: '*'
  clusterResourceWhitelist:
  - group: '*'
    kind: '*'
---
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: httpbin
spec:
  generators:
  - list:
      elements:
      - cluster: ${CLUSTER1}
  template:
    metadata:
      name: httpbin-{{cluster}}
      finalizers:
      - resources-finalizer.argocd.argoproj.io
    spec:
      project: httpbin
      source:
        repoURL: ${GITEA_HTTP}/gloo-gitops/gitops-repo.git
        targetRevision: HEAD
        path: httpbin/{{cluster}}
      destination:
        name: '{{cluster}}'
        namespace: default
      syncPolicy:
        automated:
          allowEmpty: true
          prune: true
        syncOptions:
        - ApplyOutOfSyncOnly=true