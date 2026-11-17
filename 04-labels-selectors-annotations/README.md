# 04 - Labels, Selectors, and Annotations

## Labels
Key/value pairs on `metadata.labels` used to **identify and group** objects.
Kubernetes is loosely coupled: a Service doesn't "own" pods, it **selects** them by label.

```yaml
labels:
  app.kubernetes.io/name: web          # recommended labels
  app.kubernetes.io/instance: web-prod
  app.kubernetes.io/version: "1.4.2"
  app.kubernetes.io/component: frontend
  app.kubernetes.io/part-of: shop
  app.kubernetes.io/managed-by: helm
  env: prod
```
Rules: keys use an optional `prefix/` plus a name of 63 characters or fewer. Values are 63 characters or fewer, alphanumeric, `-_.`.

## Selectors

**Equality-based**: `env=prod`, `tier!=frontend`
**Set-based**: `env in (prod,staging)`, `tier notin (cache)`, `gpu` (exists), `!gpu`

In YAML:
```yaml
selector:
  matchLabels:
    app: web
  matchExpressions:
    - { key: env, operator: In, values: [prod, staging] }
    - { key: canary, operator: DoesNotExist }
```
Operators: `In`, `NotIn`, `Exists`, `DoesNotExist`. (Node affinity also has `Gt`, `Lt`.)

Who uses selectors: Service to Pods, ReplicaSet/Deployment to Pods, NetworkPolicy, PDB, nodeSelector/affinity, and `kubectl -l`.

> A Deployment's `spec.selector` is **immutable** and must match `template.metadata.labels`.

## Annotations
Also key/value, but **not used for selection**. They hold non-identifying metadata, can be large,
and are often read by tools:

```yaml
annotations:
  kubernetes.io/change-cause: "bump to v1.4.2"
  prometheus.io/scrape: "true"
  nginx.ingress.kubernetes.io/rewrite-target: /
```

## Field selectors
Select by object fields, not labels:
```bash
kubectl get pods --field-selector status.phase=Running,spec.nodeName=kind-worker
```

## Commands
```bash
kubectl apply -f labeled-pods.yaml
kubectl get pods --show-labels
kubectl get pods -l app=web
kubectl get pods -l 'env in (prod,staging),tier!=backend'
kubectl get pods -L env,tier                       # labels as columns
kubectl label pod web-1 canary=true
kubectl label pod web-1 canary-                    # remove label
kubectl label pod web-1 env=qa --overwrite
kubectl annotate pod web-1 owner="team-a"
```
