# platform/

Cluster add-ons managed by Argo CD. Empty on purpose: filled in during

- T07: cert-manager + self-signed CA (`cert-manager-issuers/`); ingress is the Traefik that ships with k3s
- T08: kube-prometheus-stack on the workload cluster (`clusters/mgmt/kube-prometheus-stack.yaml`), Loki + Alloy for logs (`loki.yaml`, `alloy.yaml`)
- T09: Vault (mgmt) + External Secrets Operator (both clusters), `secret-store/`; runbook in docs/vault.md
- T12: Argo CD Image Updater + ImageUpdater CR for dev (`image-updater/`)
- T14: Argo Rollouts on workload (`clusters/mgmt/argo-rollouts.yaml`); demo-api is a Rollout with Traefik weighted canary

Each component gets an Application in `clusters/mgmt/` (project `platform`) that points here or at an upstream Helm chart.
- T19: custom Lua health check for TraefikService (bootstrap/argocd/values.yaml), docs/t19-broken.md
- T22/T23: RBAC roles, local account alice, GitHub SSO via Dex (secret from Vault), docs/t22-t23-access.md
- T24: Telegram notifications from Argo CD and Argo Rollouts, docs/t24-notifications.md
- T25: `argocd-metrics/`: NodePorts so Prometheus on workload scrapes Argo CD on mgmt; alerts + dashboard in kube-prometheus-stack.yaml
