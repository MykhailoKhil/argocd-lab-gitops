# argocd-lab-gitops

GitOps repository for a hands-on Argo CD lab: two k3d clusters, app-of-apps bootstrap, an ApplicationSet for dev/staging/prod, and (later) canary releases with Argo Rollouts and automatic rollback on Prometheus metrics under k6 load.

Application source code and CI live in [argocd-lab-app](https://github.com/MykhailoKhil/argocd-lab-app). CI builds images; this repo decides what runs where.

## Layout

```
bootstrap/
  argocd/values.yaml   Argo CD Helm values (first install + self-management)
  root.yaml            the only manifest applied by hand
clusters/
  mgmt/                everything the root app syncs
    project-*.yaml     AppProjects (sync-wave -20)
    argocd.yaml        Argo CD manages itself (multi-source: upstream chart + values from here)
    apps.yaml          ApplicationSet: one Application per apps/<app>/overlays/<env>/config.yaml
apps/
  demo-api/
    base/              Deployment + Service
    overlays/<env>/    kustomization.yaml (image tag, replicas) + config.yaml (cluster, namespace, autoSync)
platform/              cluster add-ons (ingress, cert-manager, monitoring, secrets, rollouts)
scripts/
  k3d-up.sh            create mgmt + workload clusters
  bootstrap.sh         install Argo CD and apply root.yaml
```

## Quickstart

Requirements: docker, k3d, kubectl, helm, yq, argocd CLI.

```bash
./scripts/k3d-up.sh
./scripts/bootstrap.sh
```

After that, every change goes through git: commit, push, and Argo CD syncs it.

## Environments

| env     | namespace    | replicas | sync      |
|---------|--------------|----------|-----------|
| dev     | demo-dev     | 1        | automatic |
| staging | demo-staging | 2        | automatic |
| prod    | demo-prod    | 3        | manual, via promotion PR |

## Progress

- [x] T01 repositories and layout
- [ ] T02 clusters
- [ ] T03 Argo CD installed
- [ ] T04 app of apps
- [ ] T05 workload cluster registered declaratively
- [ ] T06 ApplicationSet for environments
- [ ] T18 drift experiments (docs/t18-drift.md)
