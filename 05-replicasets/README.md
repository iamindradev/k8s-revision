# 05 - ReplicaSets

## Theory
A **ReplicaSet (RS)** makes sure a specified number of pod replicas matching a selector are running.
If a pod dies, the RS creates a new one. If there are too many, it deletes some.

Its reconcile loop:
```
count = pods matching selector (that it owns or can adopt)
if count < replicas: create from template
if count > replicas: delete extras
```

- **Selector + template**: the template's labels **must** match the selector.
- **Ownership**: created pods get `metadata.ownerReferences` pointing to the RS. Delete the RS
  and garbage collection deletes the pods (unless `--cascade=orphan`).
- **Adoption**: a bare pod with matching labels and no owner gets adopted. That can cause surprises.
- An RS **doesn't update** existing pods when you change the template. Only new pods get the new template.
  That is why you use **Deployments**, which manage RSs for rolling updates.

> ReplicationController is the legacy predecessor (equality selectors only). Don't use it.

## Commands
```bash
kubectl apply -f replicaset.yaml
kubectl get rs,pods -l app=web
kubectl delete pod <one-of-them>         # watch it get replaced
kubectl scale rs web-rs --replicas=5
kubectl get pod <pod> -o jsonpath='{.metadata.ownerReferences}'
kubectl delete rs web-rs --cascade=orphan  # pods survive
```
