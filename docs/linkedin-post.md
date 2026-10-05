# LinkedIn post draft (T27)

Attach: the canary-abort GIF (or the architecture diagram from the README). Edit the numbers
in brackets with what you actually measured.

---

I wanted to see how Argo CD behaves when things go wrong, so I built a small GitOps platform and broke it on purpose.

The setup: two Kubernetes clusters (k3d), Argo CD managing everything from git, Vault for secrets, Prometheus/Grafana/Loki, and a demo service released with Argo Rollouts.

The part I'm happiest with: a bad release rolls itself back.
I shipped a version that fails [50]% of requests. Argo Rollouts sent it [20]% of the traffic, the Prometheus analysis saw the error rate jump, a k6 test against the canary failed its thresholds, and within [~1 minute] all traffic was back on the old version. A Telegram message told me what happened. Nobody had to press anything.

Other things I learned by breaking them:
• Rollback in GitOps is git revert. With auto-sync on, the Argo CD rollback button is blocked, and that's a good thing.
• Self-heal only fixes fields that are in git. An extra annotation added by hand survives.
• An HPA and self-heal will fight over replicas until you tell Argo CD to ignore that field.
• Sync waves don't wait for child apps to be healthy. CRD ordering needs retries.
• A sealed Vault after a restart quietly stops your secret sync. Auto-unseal exists for a reason.

Coming from performance engineering, using k6 thresholds as a release gate felt natural: the same test that used to produce a report now decides whether a release goes live.

Repo with diagrams and runbooks: https://github.com/MykhailoKhil/argocd-lab-gitops

#GitOps #ArgoCD #Kubernetes #DevOps #SRE #k6
