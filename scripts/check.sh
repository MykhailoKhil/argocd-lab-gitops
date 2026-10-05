#!/usr/bin/env bash
# Read-only health check for the whole lab. Changes nothing.
# Usage: ./scripts/check.sh
set -uo pipefail

MGMT=k3d-mgmt
WL=k3d-workload
ok()   { printf '  \033[32mOK\033[0m   %s\n' "$*"; }
bad()  { printf '  \033[31mFAIL\033[0m %s\n' "$*"; FAILS=$((FAILS+1)); }
section() { printf '\n\033[1m%s\033[0m\n' "$*"; }
FAILS=0

section "1. Argo CD applications (mgmt)"
kubectl --context $MGMT -n argocd get applications.argoproj.io \
  -o custom-columns='NAME:.metadata.name,SYNC:.status.sync.status,HEALTH:.status.health.status' 2>/dev/null
while read -r name sync health; do
  if [[ "$sync" == "Synced" && "$health" == "Healthy" ]]; then ok "$name"
  elif [[ "$name" == *-prod && "$sync" == "OutOfSync" ]]; then ok "$name (OutOfSync is expected: prod syncs manually)"
  else bad "$name sync=$sync health=$health"; fi
done < <(kubectl --context $MGMT -n argocd get applications.argoproj.io \
  -o jsonpath='{range .items[*]}{.metadata.name} {.status.sync.status} {.status.health.status}{"\n"}{end}' 2>/dev/null)

section "2. Workload cluster registered"
if kubectl --context $MGMT -n argocd get secret cluster-workload >/dev/null 2>&1; then ok "cluster secret exists"; else bad "secret argocd/cluster-workload missing"; fi

section "3. cert-manager (mgmt)"
for ci in selfsigned lab-ca; do
  r=$(kubectl --context $MGMT get clusterissuer $ci -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null)
  [[ "$r" == "True" ]] && ok "ClusterIssuer $ci ready" || bad "ClusterIssuer $ci not ready ($r)"
done
r=$(kubectl --context $MGMT -n argocd get certificate argocd-server-tls -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null)
[[ "$r" == "True" ]] && ok "Certificate argocd-server-tls ready" || bad "Certificate argocd-server-tls not ready ($r)"

section "4. Pods not Running/Completed (workload)"
notok=$(kubectl --context $WL get pods -A --no-headers 2>/dev/null | awk '$4!="Running" && $4!="Completed"')
[[ -z "$notok" ]] && ok "all pods Running" || { bad "some pods are unhealthy:"; echo "$notok"; }

section "5. demo-api responds (workload, demo-dev)"
kubectl --context $WL -n demo-dev port-forward svc/demo-api 18082:80 >/dev/null 2>&1 & PF1=$!
sleep 3
resp=$(curl -s --max-time 5 localhost:18082/)
[[ "$resp" == *version* ]] && ok "GET / -> $resp" || bad "demo-api did not answer"
for i in $(seq 50); do curl -s -o /dev/null localhost:18082/; done   # some traffic for the metrics below
kill $PF1 2>/dev/null

section "6. Prometheus scrapes demo-api (workload)"
kubectl --context $WL -n monitoring port-forward svc/kps-prometheus 19090:9090 >/dev/null 2>&1 & PF2=$!
sleep 3
up=$(curl -s --max-time 5 'localhost:19090/api/v1/query' --data-urlencode 'query=up{namespace="demo-dev"}' | grep -o '"value":\[[^]]*\]' | head -1)
[[ "$up" == *'"1"'* ]] && ok "target demo-dev/demo-api is UP" || bad "demo-api target not UP (got: ${up:-nothing})"
n=$(curl -s --max-time 5 'localhost:19090/api/v1/query' --data-urlencode 'query=sum(http_requests_total{namespace="demo-dev"})' | grep -o '"value":\[[^]]*\]' | head -1)
[[ -n "$n" ]] && ok "http_requests_total present: $n" || bad "no http_requests_total yet (wait ~30s and re-run)"
kill $PF2 2>/dev/null

section "7. Loki receives logs (workload)"
kubectl --context $WL -n monitoring port-forward svc/loki-gateway 13100:80 >/dev/null 2>&1 & PF3=$!
sleep 3
lines=$(curl -s --max-time 5 -G 'localhost:13100/loki/api/v1/query_range' \
  --data-urlencode 'query={namespace="demo-dev"}' --data-urlencode 'limit=5' | grep -o '"values":\[\[' | wc -l)
[[ "$lines" -gt 0 ]] && ok "logs from demo-dev found in Loki" || bad "no demo-dev logs in Loki"
kill $PF3 2>/dev/null

section "Result"
[[ $FAILS -eq 0 ]] && printf '\033[32mAll checks passed.\033[0m\n' || printf '\033[31m%d check(s) failed.\033[0m\n' "$FAILS"
