# T18: drift, self-heal, prune, ignoreDifferences

All experiments run against **dev** unless stated. Keep the Argo CD UI open on `demo-api-dev`
(and its *History and rollback* tab) while you do them. Write down what you saw in the
"What I broke" section of the main README.

```bash
# works in zsh and bash (a plain W="--context ..." string is not split into words by zsh)
alias kw='kubectl --context k3d-workload'
```

## 1. Drift + self-heal

Someone "fixes" production by hand:

```bash
kw -n demo-dev label svc demo-api-stable hotfix=manual --overwrite
kw -n demo-dev get svc demo-api-stable --show-labels -w
```

Expected: the app turns **OutOfSync** for a few seconds, then self-heal removes the label.
Look at the app's *Events*: `Sync operation ... initiated automatically`.

Try a change Argo CD does NOT see:

```bash
kw -n demo-dev annotate svc demo-api-stable note=hello
```

It stays. Argo CD compares only fields that are in git (plus the last-applied state);
an extra annotation git never mentioned is not drift. Know this before you rely on self-heal
as a security control.

## 2. Self-heal off: drift stays

Turning selfHeal off in the UI does not stick: the ApplicationSet owns the Application and
puts the spec back within seconds (see it happen). To really test it, flip `autoSync: false`
in `overlays/dev/config.yaml`, push, then repeat step 1: the app stays OutOfSync until you
press Sync. Put `autoSync: true` back afterwards.

## 3. Prune

```bash
# add a throwaway resource through git
cat > apps/demo-api/overlays/dev/tmp.yaml <<'YAML'
apiVersion: v1
kind: ConfigMap
metadata:
  name: prune-me
data:
  hello: world
YAML
# add "  - tmp.yaml" under resources in overlays/dev/kustomization.yaml, commit, push
kw -n demo-dev get cm prune-me
# now remove it from kustomization.yaml + delete the file, commit, push
kw -n demo-dev get cm prune-me     # gone: prune: true
```

Variant: before removing it, annotate it in git with
`argocd.argoproj.io/sync-options: Prune=false`. After removal it survives and the UI marks
it as "requires pruning". Useful for PVCs and other things you never want auto-deleted.

## 4. Orphaned resources

```bash
kw -n demo-dev create configmap not-in-git --from-literal=a=b
```

Not tracked by any app, so Argo CD never deletes it. With `orphanedResources.warn: true` in the
`apps` AppProject the app shows an **OrphanedResourceWarning**. Clean up:
`kw -n demo-dev delete cm not-in-git`.

## 5. HPA vs Argo CD (prod)

prod has an HPA (3..6 replicas on CPU) and `hpa: true` in its config, so the ApplicationSet
adds `ignoreDifferences` for the Rollout's `/spec/replicas`.

```bash
# push CPU up: raise the k6 rate in prod (or use 'kubectl set env', then let self-heal undo it)
kw -n demo-prod set env deploy/k6-load RATE=200
kw -n demo-prod get hpa demo-api -w
```

Expected: replicas grow above 3, the app stays **Synced**.

Now see the fight: remove `hpa: true` (set it to `false`) in `overlays/prod/config.yaml`, push,
and watch `kw -n demo-prod get rollout demo-api -w`: the HPA scales up, self-heal sets
replicas back to 3, repeat. Restore `hpa: true` when done.

Note: the `set env` above is itself drift; self-heal reverts RATE to 10 within seconds. To keep
the load on, change `RATE` in git (overlays/prod patch) instead. That is the GitOps lesson in one line.
