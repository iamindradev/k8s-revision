# 06 - Deployments

## Theory
A **Deployment** manages **ReplicaSets**, which manage **Pods**, and adds:

- **Declarative rolling updates**: change the template and a new RS is created and scaled up while the old one is scaled down.
- **Rollback**: old ReplicaSets are kept (`revisionHistoryLimit`, default 10).
- **Pause/resume**: batch several changes into one rollout.

```
Deployment (web)
 ├── ReplicaSet web-7d9f8 (revision 1, replicas: 0)   <- kept for rollback
 └── ReplicaSet web-5c6b4 (revision 2, replicas: 3)   <- current
       ├── Pod web-5c6b4-abcde
       ├── Pod web-5c6b4-fghij
       └── Pod web-5c6b4-klmno
```

The RS name suffix is the **pod-template-hash**, a hash of the pod template. Only changes to
`spec.template` trigger a rollout. Changing `replicas` does not.

## Strategies

### RollingUpdate (default)
```yaml
strategy:
  type: RollingUpdate
  rollingUpdate:
    maxSurge: 25%        # how many extra pods above desired during the update
    maxUnavailable: 25%  # how many pods can be unavailable during the update
```
- `maxSurge: 1, maxUnavailable: 0`: zero-downtime, one at a time (safest).
- `maxSurge: 0, maxUnavailable: 1`: no extra capacity needed.
- Rollout only progresses when new pods become **Ready**. Readiness probes matter.

### Recreate
Kill all old pods, then start new ones. There is downtime. Use it when two versions can't run together (DB schema lock, RWO volume).

### Other patterns (done with tooling, not built-in)
- **Blue/Green**: two Deployments, then switch the Service selector. See `blue-green.yaml`.
- **Canary**: two Deployments behind one Service, split by replica ratio, or by weight with Ingress, a mesh, or Argo Rollouts / Flagger.

## Useful fields
| Field | Meaning |
|-------|---------|
| `minReadySeconds` | A pod must be ready this long to count as available |
| `progressDeadlineSeconds` | Mark the rollout as failed (`ProgressDeadlineExceeded`) after this long (default 600) |
| `revisionHistoryLimit` | How many old RSs to keep |
| `paused` | Stop reconciling the rollout |

## Commands
```bash
kubectl apply -f deployment.yaml
kubectl get deploy,rs,pods -l app=web
kubectl rollout status deploy/web
kubectl set image deploy/web nginx=nginx:1.27-alpine
kubectl annotate deploy/web kubernetes.io/change-cause="alpine image"
kubectl rollout history deploy/web
kubectl rollout history deploy/web --revision=2
kubectl rollout undo deploy/web [--to-revision=1]
kubectl rollout restart deploy/web          # re-create pods (e.g. to pick up a new ConfigMap)
kubectl rollout pause deploy/web / kubectl rollout resume deploy/web
kubectl scale deploy/web --replicas=5
kubectl create deploy web --image=nginx --replicas=3 --dry-run=client -o yaml
```

## Gotchas
- `spec.selector` is immutable.
- Don't use `latest` tags. If the template doesn't change, no rollout happens.
- Without a readiness probe, "Ready" just means "process started". Broken versions roll out fully.
- If HPA manages replicas, remove `replicas` from your YAML or GitOps will fight HPA.

## Interview questions
- Deployment vs ReplicaSet? (A Deployment adds versioned rollouts and rollback on top of RSs.)
- How does rollback work? (It scales an old RS back up and the current one down.)
- How do you get zero-downtime deploys? (Readiness probes, `maxUnavailable: 0`, a preStop sleep, PDB, graceful SIGTERM handling.)
