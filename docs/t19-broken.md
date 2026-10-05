# T19: broken manifests, Degraded apps, custom health checks

```bash
alias kw='kubectl --context k3d-workload'
```

Do each in **dev**, commit + push, watch the app in the UI, write down what you saw, then `git revert`.

| # | Break it | What Argo CD shows | Where to look | Fix |
|---|----------|--------------------|---------------|-----|
| 1 | image tag that doesn't exist (`newTag: sha-0000000`) | Synced, **Degraded** (Rollout stuck, pods `ImagePullBackOff`) | app tree → pod → Events; `kw -n demo-dev describe pod` | revert |
| 2 | invalid YAML (bad indentation in a kustomization) | **ComparisonError**, `Unknown` sync | app → *App conditions*; `validate` workflow fails on the PR | revert |
| 3 | unknown field (`spec.replicaz: 2` in the Rollout patch) | sync **Failed**: field not declared in schema | app → *Sync status* → operation message | revert |
| 4 | readiness probe on a wrong path (`/nope`) | **Progressing** forever, then canary aborted by analysis/k6 | Rollout events; `kubectl argo rollouts get rollout demo-api` | revert |

Lesson: 2 and 3 never reach the cluster (caught at render/apply time); 1 and 4 do, and only
health checks (and the canary) stop them from hurting users.

## Custom health check (Lua)

Argo CD has no built-in health for Traefik's `TraefikService`. `bootstrap/argocd/values.yaml`
adds one (`resource.customizations.health.traefik.io_TraefikService`):
no backend services -> **Degraded**, otherwise **Healthy**.

Test it: in a branch, empty `spec.weighted.services` of the TraefikService (patch in an overlay),
sync dev, see the resource and the app turn Degraded with the message from the Lua script.
Without the custom check the same object shows as plain Healthy/unknown.
