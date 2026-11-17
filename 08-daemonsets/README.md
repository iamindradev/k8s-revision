# 08 - DaemonSets

## Theory
A **DaemonSet** runs **one pod per node** (or per selected node). When a node joins, a pod is
added. When a node leaves, the pod is garbage-collected.

Typical uses:
- Log collectors (Fluent Bit, Promtail)
- Node monitoring (node-exporter, Datadog agent)
- Networking (kube-proxy, CNI agents like Calico or Cilium)
- Storage drivers (CSI node plugins)

### How scheduling works
The DaemonSet controller creates a pod per eligible node and sets node affinity for that node.
The default scheduler then binds it. DaemonSet pods automatically tolerate taints such as
`node.kubernetes.io/not-ready` and `unreachable`, so they keep running on unhealthy nodes.

To run on **control-plane nodes**, add a toleration for `node-role.kubernetes.io/control-plane:NoSchedule`.

To run on **a subset** of nodes, use `nodeSelector` or `affinity` in the pod template.

### Update strategies
- `RollingUpdate` (default): `maxUnavailable` (default 1) and `maxSurge` (default 0).
- `OnDelete`: update only when a pod is deleted manually.

### Common pod settings for DaemonSets
`hostNetwork: true`, `hostPID`, `hostPath` volumes, and a `priorityClassName` such as `system-node-critical`.
These are powerful. Restrict them with Pod Security.

## Commands
```bash
kubectl apply -f daemonset.yaml
kubectl get ds -o wide
kubectl get pods -l app=node-agent -o wide     # one per node
kubectl rollout status ds/node-agent
kubectl label node kind-worker disk=ssd        # for daemonset-node-selector.yaml
```
