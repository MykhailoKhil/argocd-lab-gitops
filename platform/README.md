# platform/

Cluster add-ons managed by Argo CD. Empty on purpose: filled in during

- T07: cert-manager + self-signed CA (`cert-manager-issuers/`); ingress is the Traefik that ships with k3s
- T08: kube-prometheus-stack, Loki
- T09: sealed-secrets or external-secrets
- T14: Argo Rollouts

Each component gets an Application in `clusters/mgmt/` (project `platform`) that points here or at an upstream Helm chart.
