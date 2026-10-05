#!/usr/bin/env bash
# T03 + T04: first install of Argo CD (chicken-and-egg), then hand control over to git.
set -euo pipefail
cd "$(dirname "$0")/.."

CHART_VERSION=$(yq '.spec.sources[0].targetRevision' clusters/mgmt/argocd.yaml)

kubectl config use-context k3d-mgmt
helm repo add argo https://argoproj.github.io/argo-helm >/dev/null 2>&1 || true
helm repo update argo >/dev/null

helm upgrade --install argocd argo/argo-cd \
  --version "$CHART_VERSION" \
  --namespace argocd --create-namespace \
  -f bootstrap/argocd/values.yaml \
  --wait

kubectl apply -f bootstrap/root.yaml

echo
echo "Initial admin password:"
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d; echo
echo
echo "UI:  kubectl -n argocd port-forward svc/argocd-server 8081:80  ->  http://localhost:8081"
echo "CLI: argocd login localhost:8081 --username admin --insecure --grpc-web"
echo "Then change the password (argocd account update-password) and delete argocd-initial-admin-secret."
