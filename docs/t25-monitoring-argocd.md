# T25: monitoring Argo CD itself

Prometheus lives on workload, Argo CD on mgmt. `platform/argocd-metrics` exposes the
controller (30882), server (30883) and repo-server (30884) metrics as NodePorts on the mgmt node;
kube-prometheus-stack scrapes `k3d-mgmt-server-0:<port>` over the shared docker network.

Check:
- Prometheus → Status → Targets: jobs `argocd-application-controller`, `argocd-server`, `argocd-repo-server` UP
- query: `argocd_app_info` (one series per app, with sync_status and health_status labels)
- Grafana → folder **Lab** → *ArgoCD* dashboard (grafana.com 14584)

Alerts (`additionalPrometheusRulesMap` in kube-prometheus-stack.yaml):

| alert | when |
|-------|------|
| ArgoCDAppOutOfSync | an app OutOfSync for 15 min (fires during a sync window too: expected) |
| ArgoCDAppDegraded | an app Degraded for 5 min |
| ArgoCDMetricsDown | a scrape target down for 5 min |

Test: put a test sync window on dev (T21) and change something in dev; after 15 min the alert
fires in Prometheus → Alerts. Faster: temporarily change `for: 15m` to `1m`.
