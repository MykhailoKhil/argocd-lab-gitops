# platform/

Cluster add-ons managed by Argo CD. Empty on purpose: filled in during

- T07: cert-manager + self-signed CA (`cert-manager-issuers/`); ingress is the Traefik that ships with k3s
- T08: kube-prometheus-stack on the workload cluster (`clusters/mgmt/kube-prometheus-stack.yaml`), Loki + Alloy for logs (`loki.yaml`, `alloy.yaml`)
- T09: Vault (mgmt) + External Secrets Operator (both clusters), `secret-store/`; runbook in docs/vault.md
- T12: Argo CD Image Updater + ImageUpdater CR for dev (`image-updater/`)
- T14: Argo Rollouts on workload (`clusters/mgmt/argo-rollouts.yaml`); demo-api is a Rollout with Traefik weighted canary

Each component gets an Application in `clusters/mgmt/` (project `platform`) that points here or at an upstream Helm chart.
