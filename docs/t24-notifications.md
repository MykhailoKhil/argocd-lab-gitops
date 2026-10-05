# T24: Telegram notifications

Two senders, one bot:

| who | events | config |
|-----|--------|--------|
| Argo CD (mgmt) | app deployed / sync failed / health Degraded | `bootstrap/argocd/values.yaml` → `notifications` |
| Argo Rollouts (workload) | canary aborted / completed | `clusters/mgmt/argo-rollouts.yaml` + annotations in `apps/demo-api/base/rollout.yaml` |

## Setup

1. Telegram: talk to **@BotFather** → `/newbot` → copy the token.
2. Send any message to your new bot, then get your chat id:
   ```bash
   curl -s "https://api.telegram.org/bot<TOKEN>/getUpdates" | jq '.result[0].message.chat.id'
   ```
3. Token into Vault:
   ```bash
   v kv put secret/notifications/telegram token=<TOKEN>
   ```
4. Chat id into git (it is not a secret, only an address):
   ```bash
   grep -rl --exclude-dir=.git --exclude-dir=docs TELEGRAM_CHAT_ID . | xargs sed -i '' "s/TELEGRAM_CHAT_ID/<CHAT_ID>/g"
   git commit -am "T24: telegram chat id" && git push
   ```

## Test

- deploy anything to dev → "✅ demo-api-dev deployed"
- T17 again (FAULT_ERROR_RATE=0.5) → Rollouts: "rollout aborted", Argo CD: "⚠️ demo-api-dev is Degraded"

Debug: `kubectl --context k3d-mgmt -n argocd logs deploy/argocd-notifications-controller`
and `kubectl --context k3d-workload -n argo-rollouts logs deploy/argo-rollouts | grep -i notif`.
