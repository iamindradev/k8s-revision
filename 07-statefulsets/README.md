# 07 - StatefulSets

## Theory
A **StatefulSet** is for workloads where each replica needs a **stable identity**: databases,
Kafka, ZooKeeper, etcd, Elasticsearch.

| Guarantee | Deployment | StatefulSet |
|-----------|-----------|-------------|
| Pod names | random (`web-5c6b4-xk2p`) | ordinal (`db-0`, `db-1`, `db-2`) |
| Network identity | none | stable DNS `db-0.db-headless.ns.svc.cluster.local` |
| Storage | shared or none | **per-pod PVC** from `volumeClaimTemplates`, kept across reschedules |
| Start/stop order | parallel | ordered by default (0, 1, 2 up; 2, 1, 0 down) |

### Required: a headless Service
`clusterIP: None`. It creates DNS records for each pod instead of one virtual IP.
`spec.serviceName` must point to it.

### Pod management policy
- `OrderedReady` (default): pod N+1 starts only after pod N is Running and Ready.
- `Parallel`: start and delete all at once (scaling only; updates still follow the update strategy).

### Update strategies
- `RollingUpdate` (default): updates pods in **reverse ordinal** order, one at a time.
  - `partition: N`: only pods with ordinal >= N are updated (staged or canary rollouts).
  - `maxUnavailable` (v1.24+ beta).
- `OnDelete`: pods update only when you delete them manually.

### PVC retention
```yaml
persistentVolumeClaimRetentionPolicy:
  whenDeleted: Retain   # or Delete
  whenScaled: Retain
```
By default **PVCs are not deleted** when you scale down or delete the StatefulSet. That protects your data.

## Gotchas
- A StatefulSet doesn't make your app clustered. The app must handle replication and leader election itself (that is what operators do).
- If a node dies, the pod isn't automatically force-replaced. Kubernetes avoids two pods with the same identity (at-most-one semantics).
- Use an init container or the ordinal (`$(hostname)` ends in `-N`) to configure primary vs replica.

## Commands
```bash
kubectl apply -f statefulset.yaml
kubectl get sts,pods,pvc -l app=nginx-sts
kubectl run dns --rm -it --image=busybox:1.36 -- nslookup web-0.nginx-headless
kubectl scale sts web --replicas=5
kubectl delete pod web-1        # comes back as web-1 with the same PVC
kubectl rollout status sts/web
kubectl patch sts web -p '{"spec":{"updateStrategy":{"rollingUpdate":{"partition":2}}}}'
```
