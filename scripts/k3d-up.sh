#!/usr/bin/env bash
# T02: two local clusters on one docker network, so Argo CD in "mgmt" can reach "workload".
set -euo pipefail

NET=argocd-lab
docker network inspect "$NET" >/dev/null 2>&1 || docker network create "$NET"

# mgmt: Argo CD + platform. Host ports 8080/8443 -> ingress (T07).
k3d cluster list mgmt >/dev/null 2>&1 || k3d cluster create mgmt \
  --network "$NET" --servers 1 --agents 1 \
  -p "8080:80@loadbalancer" -p "8443:443@loadbalancer" \
  --k3s-arg "--disable=traefik@server:0"

# workload: application workloads (T05).
k3d cluster list workload >/dev/null 2>&1 || k3d cluster create workload \
  --network "$NET" --servers 1 --agents 2 \
  -p "9080:80@loadbalancer" -p "9443:443@loadbalancer" \
  --k3s-arg "--disable=traefik@server:0"

kubectl config use-context k3d-mgmt
echo
echo "Contexts: k3d-mgmt, k3d-workload"
echo "From inside mgmt, the workload API is https://k3d-workload-server-0:6443"
