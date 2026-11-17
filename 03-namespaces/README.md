# 03 - Namespaces

## Theory

A **Namespace** is a virtual cluster inside a physical cluster. It provides:

- **Name scoping**: `web` in `dev` and `web` in `prod` are different objects.
- **A unit for policy**: RBAC, ResourceQuota, LimitRange, NetworkPolicy, and Pod Security all apply per namespace.
- **Not hard isolation**: pods can still reach each other across namespaces unless NetworkPolicy blocks it.

### Built-in namespaces
| Namespace | Purpose |
|-----------|---------|
| `default` | Where things go if you don't specify a namespace |
| `kube-system` | Control plane and add-ons (CoreDNS, kube-proxy) |
| `kube-public` | Readable by everyone, including unauthenticated users (cluster-info) |
| `kube-node-lease` | Node heartbeat Lease objects |

### Namespaced vs cluster-scoped
- Namespaced: Pod, Deployment, Service, ConfigMap, Secret, Role, PVC, and more
- Cluster-scoped: Node, PersistentVolume, StorageClass, ClusterRole, Namespace, CRD

```bash
kubectl api-resources --namespaced=false
```

### DNS across namespaces
A Service `db` in namespace `data` is reachable at:
`db.data.svc.cluster.local` (or `db.data` for short; just `db` works only from within the same namespace).

### Deleting a namespace

`kubectl delete ns dev` is one of the most destructive commands in Kubernetes. It deletes
**every namespaced object inside**: Deployments, Pods, Services, ConfigMaps, Secrets, PVCs,
Roles, RoleBindings, ServiceAccounts, and every custom resource. There is **no undo and no recycle bin**.
Restoring needs a backup (Velero) or re-applying from Git.

#### What gets deleted, and what doesn't
| Deleted with the namespace | Not deleted (cluster-scoped, lives outside it) |
|----------------------------|------------------------------------------------|
| All namespaced objects (`kubectl api-resources --namespaced=true`) | Nodes, StorageClasses, CRDs, ClusterRoles |
| PVCs. Their PVs are then deleted **or** kept depending on `reclaimPolicy` (`Delete` destroys the actual disk and its data, `Retain` keeps it) | PersistentVolumes with `Retain` (left `Released`) |
| ServiceAccounts and their tokens | ClusterRoleBindings that point at those ServiceAccounts (left dangling) |
| Custom resources (and whatever their operators clean up through finalizers) | Cloud resources an operator created **without** a finalizer (orphaned) |

#### What happens step by step
1. The API server sets `metadata.deletionTimestamp` on the Namespace, and its `status.phase` becomes **`Terminating`**.
   From now on, **no new objects** can be created in it.
2. The **namespace controller** (in kube-controller-manager) runs **discovery** to list every
   namespaced resource type in the cluster, including CRDs and aggregated APIs.
3. It **deletes all objects** of every type in the namespace.
4. Each object is only truly removed once **its own** `metadata.finalizers` list is empty.
   For example, a PVC waits for `kubernetes.io/pvc-protection` until no pod uses it, and a custom resource waits for its operator's cleanup finalizer.
5. When nothing is left, the controller removes the namespace's own finalizer (`kubernetes`, in
   `spec.finalizers`), and the Namespace object disappears.

#### What is a finalizer?
A **finalizer** is a string in an object's `metadata.finalizers` list that says *"don't remove me yet,
someone has cleanup to do."* Deleting an object with finalizers only **marks** it (`deletionTimestamp`).
The controller that owns the finalizer does its cleanup (deletes a cloud load balancer, a DNS record,
a database user) and then **removes its string**. When the list is empty, the API server deletes the object.

> If the controller that owns a finalizer is **gone**, nobody ever removes the string, and the object
> (and therefore its namespace) stays in `Terminating` **forever**.

#### Why a namespace gets stuck in `Terminating`
| Cause | How it happens | Condition you'll see in `status.conditions` |
|-------|----------------|---------------------------------------------|
| **Finalizer with no controller** (most common) | An operator was uninstalled (or crashed, or lost RBAC) before its custom resources were deleted | `NamespaceFinalizersRemaining`, `NamespaceContentRemaining` |
| **A broken aggregated API** | An `APIService` is unavailable (often metrics-server is down), so discovery fails and the controller can't be sure it deleted everything | `NamespaceDeletionDiscoveryFailure` |
| **Deleted CRD, leftover objects** | The CRD was removed while custom resources with finalizers still existed | `NamespaceContentRemaining` |
| **Webhook blocking deletes** | A validating webhook whose service is down rejects or times out on DELETE requests | `NamespaceDeletionContentFailure` |
| **Pods that won't terminate** | The node is unreachable, so the kubelet never confirms the pod is gone | `NamespaceContentRemaining` |

#### How to diagnose it
```bash
# 1. Why is it stuck? Read the conditions. The message names the blocking resource or finalizer.
kubectl get ns dev -o jsonpath='{range .status.conditions[*]}{.type}{": "}{.message}{"\n"}{end}'

# 2. What objects are still inside? (loops over every namespaced resource type)
kubectl api-resources --verbs=list --namespaced -o name \
  | xargs -n 1 kubectl get -n dev --show-kind --ignore-not-found

# 3. Which finalizers are holding a leftover object?
kubectl get <kind> <name> -n dev -o jsonpath='{.metadata.finalizers}'

# 4. Is an aggregated API broken? (AVAILABLE=False)
kubectl get apiservices | grep False
```

#### How to fix it, safest option first
1. **Bring the controller back.** Reinstall the operator, or fix its crash or RBAC, so it runs its
   cleanup and removes its own finalizers. This is the only option that also cleans up
   **external** resources (cloud LBs, disks, DNS). The other options below leave those behind.
2. **Fix the broken APIService.** Repair metrics-server, or delete the stale APIService
   (`kubectl delete apiservice v1beta1.metrics.k8s.io` if metrics-server was removed on purpose).
   Deletion then continues by itself.
3. **Remove the finalizer from a specific leftover object.** Only do this once you've accepted that its cleanup won't happen:
   ```bash
   kubectl patch <kind> <name> -n dev --type=merge -p '{"metadata":{"finalizers":null}}'
   ```
4. **Last resort: force-finalize the namespace itself.** This skips all remaining cleanup. Any
   objects still in etcd become invisible orphans and can **reappear** if you recreate a namespace with the same name.
   ```bash
   kubectl get ns dev -o json | jq '.spec.finalizers = []' \
     | kubectl replace --raw /api/v1/namespaces/dev/finalize -f -
   ```

> **Correct uninstall order:** delete the custom resources **first**, wait until they're gone,
> **then** uninstall the operator, **then** delete the CRDs and the namespace.
> Doing it in the opposite order is the number one cause of stuck namespaces.

#### Protecting important namespaces
- **RBAC**: don't give `delete` on `namespaces` to people or CI pipelines that don't need it.
- **Admission policy**: block deleting namespaces labeled `protected=true` (see `protect-namespace-policy.yaml`).
- **Backups**: Velero (or a similar tool) for objects and volume snapshots. GitOps (Argo CD, Flux) so manifests can be re-applied.
- **Check before you type**: `kubectl config current-context`. Many "we deleted prod" incidents were the wrong context.

#### Try it: create a stuck namespace and fix it
```bash
kubectl apply -f stuck-namespace-demo.yaml        # a ConfigMap with a finalizer no controller owns
kubectl delete ns stuck-demo --wait=false
kubectl get ns stuck-demo                         # STATUS: Terminating ... forever
kubectl get ns stuck-demo -o jsonpath='{.status.conditions[?(@.type=="NamespaceFinalizersRemaining")].message}'
kubectl patch configmap held -n stuck-demo --type=merge -p '{"metadata":{"finalizers":null}}'
kubectl get ns stuck-demo                         # gone after a few seconds
```

## Commands
```bash
kubectl get ns
kubectl create ns dev
kubectl apply -f namespace.yaml
kubectl get pods -n dev
kubectl get pods -A                                   # all namespaces
kubectl config set-context --current --namespace=dev  # change default ns
kubectl delete ns dev
```
