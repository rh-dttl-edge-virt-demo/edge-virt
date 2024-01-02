#!/bin/bash -e

cat <<EOF >bootstrap/ssh-keys.yaml
---
apiVersion: v1
kind: Secret
metadata:
  name: git-repo
  namespace: openshift-gitops
  labels:
    argocd.argoproj.io/secret-type: repository
type: Opaque
data:
  type: Z2l0
  url: Z2l0QGdpdGh1Yi5jb206cmgtZHR0bC1lZGdlLXZpcnQtZGVtby9lZGdlLXZpcnQuZ2l0
  sshPrivateKey: $(base64 -w0 install/argo_ed25519)
  enableLfs: dHJ1ZQ==
EOF
