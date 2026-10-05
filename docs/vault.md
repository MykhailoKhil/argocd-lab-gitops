# Vault + External Secrets (T09)

```
Vault (mgmt, ns vault)  <--  ESO (mgmt)      -> Secret argocd/cluster-workload   (Argo CD cluster registration)
        ^ NodePort 30820 <--  ESO (workload)  -> Secret monitoring/grafana-admin  (Grafana login)
```

Git holds only `ExternalSecret` objects (pointers). Values live in Vault.
The one secret created by hand is the read-only Vault token for ESO (`external-secrets/vault-token` in each cluster).

## 1. Initialise and unseal (once)

```bash
kubectl --context k3d-mgmt -n vault exec vault-0 -- vault operator init -key-shares=1 -key-threshold=1 -format=json > ~/vault-init.json
# keep ~/vault-init.json OUT of git: it holds the unseal key and the root token

UNSEAL=$(jq -r '.unseal_keys_b64[0]' ~/vault-init.json)
kubectl --context k3d-mgmt -n vault exec vault-0 -- vault operator unseal "$UNSEAL"
```

After every restart of the k3d cluster (or of the vault-0 pod) Vault is **sealed** again. Unseal with the same command.
In production this is solved with auto-unseal (cloud KMS / Transit), not by hand.

## 2. Enable KV and write the secrets

```bash
export VAULT_TOKEN=$(jq -r '.root_token' ~/vault-init.json)
v() { kubectl --context k3d-mgmt -n vault exec -i vault-0 -- env VAULT_TOKEN=$VAULT_TOKEN vault "$@"; }

v secrets enable -path=secret kv-v2

# Grafana admin
v kv put secret/grafana/admin admin-user=admin admin-password="$(openssl rand -base64 18)"

# Argo CD -> workload cluster (same values as the manual secret from T05)
TOKEN=$(kubectl --context k3d-workload -n kube-system get secret argocd-manager-token -o jsonpath='{.data.token}' | base64 -d)
CA=$(kubectl --context k3d-workload -n kube-system get secret argocd-manager-token -o jsonpath='{.data.ca\.crt}')
v kv put secret/argocd/clusters/workload server=https://k3d-workload-server-0:6443 bearerToken="$TOKEN" caData="$CA"
```

## 3. Read-only policy and token for ESO

```bash
v policy write eso-read - <<'POLICY'
path "secret/data/*"     { capabilities = ["read"] }
path "secret/metadata/*" { capabilities = ["read", "list"] }
POLICY

ESO_TOKEN=$(v token create -policy=eso-read -orphan -period=768h -field=token)

for ctx in k3d-mgmt k3d-workload; do
  kubectl --context $ctx create namespace external-secrets --dry-run=client -o yaml | kubectl --context $ctx apply -f -
  kubectl --context $ctx -n external-secrets create secret generic vault-token --from-literal=token="$ESO_TOKEN"
done
```

`-period` makes it a periodic token: it never expires as long as it is renewed within 768h (ESO does not renew it; re-create it monthly or move to Kubernetes auth).

## 4. Hand the manual cluster secret over to ESO

The `cluster-workload` Secret created by hand in T05 blocks ESO from owning it. Once the
ExternalSecret exists, delete the manual one; ESO recreates it from Vault within seconds:

```bash
kubectl --context k3d-mgmt -n argocd get externalsecret cluster-workload   # wait for SecretSynced
kubectl --context k3d-mgmt -n argocd delete secret cluster-workload
kubectl --context k3d-mgmt -n argocd get externalsecret,secret cluster-workload
```

## 5. Check

```bash
kubectl --context k3d-mgmt get clustersecretstore vault        # STATUS Valid, READY True
kubectl --context k3d-workload get clustersecretstore vault    # same
kubectl --context k3d-workload -n monitoring get externalsecret grafana-admin
kubectl --context k3d-workload -n monitoring get secret grafana-admin -o jsonpath='{.data.admin-password}' | base64 -d; echo
```

Vault UI: https://vault.localtest.me:8443 (through the mgmt Traefik port-forward), log in with the root token.

## Next steps

- Kubernetes auth instead of a static token (no "secret zero").
- Rotate the Grafana password in Vault and watch ESO update the Secret (refreshInterval 1h, or annotate the ExternalSecret with `force-sync=$(date +%s)`).

## T12: git credentials for Image Updater

Create a GitHub fine-grained token: Settings → Developer settings → Fine-grained tokens →
repository access *only* `argocd-lab-gitops`, permission **Contents: Read and write**. Then:

```bash
v kv put secret/argocd/image-updater-git username=MykhailoKhil password=<github_pat_...>
```

ESO turns it into Secret `argocd/git-creds` (platform/image-updater/git-creds.yaml).

## T23/T24: more secrets

```bash
v kv put secret/argocd/dex-github clientID=<id> clientSecret=<secret>     # t22-t23-access.md
v kv put secret/notifications/telegram token=<bot token>                  # t24-notifications.md
```
