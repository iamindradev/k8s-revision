# 01 - Kubernetes Architecture

## What Kubernetes is

Kubernetes is a **container orchestrator**. You declare *desired state* ("run 3 copies of
this image, reachable on port 80") and Kubernetes keeps *actual state* matching it:
scheduling, restarting, scaling, networking, and rolling out changes.

The key idea is **declarative + reconciliation**. You never say "start a container".
You say "there should be 3", and controllers keep working until there are.

## Components

```
                  ┌──────────────── CONTROL PLANE ────────────────┐
 kubectl ──HTTPS──►  kube-apiserver  ◄──►  etcd (key-value store)  │
                  │      ▲    ▲                                    │
                  │      │    └── kube-scheduler                   │
                  │      └─────── kube-controller-manager          │
                  │               cloud-controller-manager         │
                  └──────┬─────────────────────────────────────────┘
                         │ watch / update
        ┌────────────────┼─────────────────┐
   ┌────▼─────┐     ┌────▼─────┐      ┌────▼─────┐
   │  NODE 1  │     │  NODE 2  │      │  NODE 3  │
   │ kubelet  │     │ kubelet  │      │ kubelet  │
   │kube-proxy│     │kube-proxy│      │kube-proxy│
   │containerd│     │containerd│      │containerd│
   │  pods... │     │  pods... │      │  pods... │
   └──────────┘     └──────────┘      └──────────┘
```

### Control plane

| Component | Job |
|-----------|-----|
| **kube-apiserver** | The front door. A REST API that authenticates, authorizes, runs admission, validates, and persists to etcd. **Only the API server talks to etcd.** Every other component talks to the API server. |
| **etcd** | Distributed, consistent (Raft) key-value store. Holds all cluster state. Back it up. |
| **kube-scheduler** | Watches pods with no `nodeName`, then **filters** nodes (resources, taints, affinity) and **scores** them, then binds the pod to the best node. |
| **kube-controller-manager** | Runs built-in controllers: Deployment, ReplicaSet, Node, Job, EndpointSlice, ServiceAccount, Namespace, and others. Each is a reconcile loop. |
| **cloud-controller-manager** | Cloud-specific logic: LoadBalancers, node lifecycle, routes. |

### Worker node

| Component | Job |
|-----------|-----|
| **kubelet** | Agent on every node. Watches pods bound to its node and makes them run through the CRI. Runs probes and reports status. |
| **container runtime** | containerd or CRI-O. Pulls images and runs containers. (Docker as a runtime was removed in v1.24.) |
| **kube-proxy** | Programs iptables/IPVS (or nftables) so Service IPs route to pod IPs. Some CNIs (Cilium) replace it with eBPF. |
| **CNI plugin** | Gives each pod an IP and connects pods across nodes (Calico, Cilium, Flannel). |

Add-ons: CoreDNS (service discovery), metrics-server, Ingress controller.

## What happens on `kubectl apply -f deployment.yaml`

1. kubectl sends a request to the **API server**.
2. **Authentication** (who are you: cert, token, OIDC), then **Authorization** (RBAC: may you?).
3. **Mutating admission** (defaults, sidecar injection), then **schema validation**, then **validating admission** (policies).
4. The object is persisted to **etcd**.
5. The **Deployment controller** sees the new Deployment and creates a **ReplicaSet**.
6. The **ReplicaSet controller** sees it wants 3 pods and has 0, so it creates 3 **Pod** objects (no node yet).
7. The **scheduler** sees unscheduled pods and picks a node for each (sets `spec.nodeName`).
8. The **kubelet** on that node sees a pod for itself: CNI sets up networking, the runtime pulls the image, and the containers start.
9. The kubelet reports status. EndpointSlice controller adds ready pod IPs to Services, and kube-proxy updates rules.

Note that nobody calls anybody directly. Every component **watches** the API server and reacts.
This is level-triggered and self-healing: if anything crashes, it reconciles again when it restarts.

## Kubernetes object anatomy

Every object has the same shape:

```yaml
apiVersion: apps/v1        # API group/version
kind: Deployment           # type
metadata:                  # name, namespace, labels, annotations, uid, resourceVersion
  name: web
spec:                      # DESIRED state (you write this)
  ...
status:                    # ACTUAL state (controllers write this)
  ...
```

## Commands

```bash
kubectl get nodes -o wide
kubectl get pods -n kube-system           # control-plane pods on kind/kubeadm
kubectl cluster-info
kubectl api-resources
kubectl api-versions
kubectl explain deployment.spec --recursive | less
kubectl get --raw /healthz
kubectl get events -A --sort-by=.lastTimestamp
```

## Interview questions

- What happens if etcd goes down? (Running pods keep running, but there are no changes or scheduling. The API is read-only or unavailable.)
- What happens if the scheduler dies? (Existing pods are fine. New pods stay `Pending`.)
- Why does only the API server talk to etcd? (Single point for authn, authz, admission, validation, and watch caching.)
- Static pods: the kubelet runs manifests from `/etc/kubernetes/manifests` directly. This is how the control plane bootstraps itself on kubeadm.
