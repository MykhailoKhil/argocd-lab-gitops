# T22 + T23: who may do what

## T22: RBAC and AppProjects

Policy lives in `bootstrap/argocd/values.yaml` (`configs.rbac.policy.csv`):

| subject | role | may |
|---------|------|-----|
| everyone logged in | `role:readonly` (default) | see everything |
| `alice` (local account) | `role:apps-dev` | see project `apps`, sync + restart `*-dev`, read logs; **no** access to project `platform` |
| `MykhailoKhil` (GitHub, via SSO) | `role:admin` | everything |

AppProjects add a second fence that applies to every user and every automation:
`apps` may only deploy namespaced resources into `demo-*` namespaces, `platform` may deploy anywhere.

```bash
argocd account update-password --account alice --current-password <admin-password> --new-password <new>
argocd admin settings rbac can alice sync applications 'apps/demo-api-dev'  --namespace argocd   # Yes
argocd admin settings rbac can alice sync applications 'apps/demo-api-prod' --namespace argocd   # No
argocd admin settings rbac can alice get  applications 'platform/vault'     --namespace argocd   # No
```

Then log in as alice in the UI: prod's Sync button is refused, `platform` apps are invisible.

## T23: SSO with GitHub (Dex)

1. GitHub → Settings → Developer settings → OAuth Apps → New:
   - Homepage URL: `https://argocd.localtest.me:8443`
   - Callback URL: `https://argocd.localtest.me:8443/api/dex/callback`
2. Put the credentials in Vault (see vault.md for `v`):
   ```bash
   v kv put secret/argocd/dex-github clientID=<id> clientSecret=<secret>
   ```
3. Push. ESO creates `argocd/argocd-dex-github`, Dex starts, the login page shows **Log in via GitHub**.
4. Log in. You land as `MykhailoKhil` with `role:admin`.
5. Once that works, disable the local admin: add `admin.enabled: "false"` under `configs.cm`, push.
   Keep `~/vault-init.json` and alice as break-glass.

The UI must be reached at exactly `https://argocd.localtest.me:8443` (mgmt Traefik on 8443:
`k3d cluster edit mgmt --port-add "8443:443@loadbalancer"` or a port-forward), otherwise the
OAuth redirect does not match.

If you are logged in but have no rights, check what Argo CD sees:
UI → User info. RBAC matches on `preferred_username` (your GitHub login).
