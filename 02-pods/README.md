# 02 - Pods

## What is a Pod?

A **Pod** is the smallest deployable unit in Kubernetes. It is a wrapper around **one or more
containers** that:

- share a **network namespace**: one IP, one port space. Containers talk over `localhost`.
- can share **volumes**.
- are **scheduled together** on the same node and live and die together.

Think of a pod as a "logical host" and the containers as processes on it.

> You rarely create bare pods in production. A bare pod is **not rescheduled** if its node dies.
> Use a controller (Deployment, StatefulSet, Job) that creates pods from a `template`.

## Pod lifecycle

| Phase | Meaning |
|-------|---------|
| `Pending` | Accepted, but not running yet: waiting for scheduling or pulling images |
| `Running` | Bound to a node, and at least one container is running |
| `Succeeded` | All containers exited 0 and won't restart |
| `Failed` | All containers terminated, and at least one failed |
| `Unknown` | The node is unreachable |

**Container states:** `Waiting` (with a reason such as `ContainerCreating`, `ImagePullBackOff`, or `CrashLoopBackOff`), `Running`, `Terminated`.

**Pod conditions:** `PodScheduled`, `Initialized`, `ContainersReady`, `Ready`.

### restartPolicy
- `Always` (default; required for Deployments)
- `OnFailure` (Jobs)
- `Never`

Restarts use exponential backoff (10s, 20s, 40s, up to 5 min). That backoff is the `CrashLoopBackOff` status.

### Termination (graceful shutdown)
1. The pod is marked `Terminating` and removed from Service endpoints.
2. The `preStop` hook runs (if defined).
3. **SIGTERM** is sent to PID 1 of each container.
4. Kubernetes waits for `terminationGracePeriodSeconds` (default 30).
5. **SIGKILL**.

## Key spec fields

```yaml
spec:
  containers:
    - name, image, imagePullPolicy (Always | IfNotPresent | Never)
      command   # overrides the image's ENTRYPOINT
      args      # overrides the image's CMD
      ports, env, envFrom, resources, volumeMounts
      livenessProbe, readinessProbe, startupProbe, lifecycle, securityContext
  initContainers, volumes, restartPolicy, nodeSelector, affinity, tolerations
  serviceAccountName, securityContext, terminationGracePeriodSeconds, hostNetwork, dnsPolicy
```

### Field-by-field: one-line definitions

**Container-level fields** (set separately for each container under `spec.containers[]`)

| Field | One-line definition |
|-------|---------------------|
| `name` | Unique name of the container inside the pod. Used by `kubectl logs -c` and `exec -c`. |
| `image` | The container image to run, e.g. `nginx:1.27`. |
| `imagePullPolicy` | When to pull the image: `Always` (every start), `IfNotPresent` (only if not cached), `Never` (only use the local copy). |
| `command` | The executable to run. Replaces the image's `ENTRYPOINT`. |
| `args` | Arguments passed to the command. Replaces the image's `CMD`. |
| `ports` | Ports the container listens on. Mostly documentation, plus names you can reference (e.g. `targetPort: http`). |
| `env` | Sets **individual** environment variables, one by one (a literal value, or one key from a ConfigMap, Secret, or pod field). |
| `envFrom` | Imports **all keys** of a ConfigMap or Secret as environment variables at once. |
| `resources` | CPU and memory `requests` (reserved, used for scheduling) and `limits` (maximum: CPU is throttled, memory is OOMKilled). |
| `volumeMounts` | **Where** a pod-level volume appears inside this container's filesystem (`mountPath`, `readOnly`, `subPath`). |
| `livenessProbe` | "Is the container alive?" If it fails, the kubelet **restarts** the container. |
| `readinessProbe` | "Can it serve traffic?" If it fails, the pod is **removed from Service endpoints**. No restart. |
| `startupProbe` | "Has it finished starting?" Liveness and readiness probes stay paused until it succeeds. Meant for slow-starting apps. |
| `lifecycle` | Hooks: `postStart` runs right after the container starts, `preStop` runs just before it is stopped (graceful shutdown). |
| `securityContext` (container) | Security settings for **this one container**: user, read-only root filesystem, capabilities, privilege escalation, privileged mode. |

**Pod-level fields** (directly under `spec`, apply to the whole pod)

| Field | One-line definition |
|-------|---------------------|
| `containers` | The main app containers. They run **together, in parallel**, for the pod's whole life. |
| `initContainers` | Containers that run **one by one, before** the main containers, and must each exit successfully (setup tasks). |
| `volumes` | **Declares** the storage available to the pod (emptyDir, configMap, secret, PVC, ...). Containers then mount it with `volumeMounts`. |
| `restartPolicy` | What the kubelet does when a container exits: `Always`, `OnFailure`, or `Never`. |
| `nodeSelector` | Simple hard rule: run only on nodes that have **all** these exact labels. |
| `affinity` | Advanced placement rules (expressions, hard or soft, near or away from other pods). |
| `tolerations` | Lets the pod be scheduled on nodes that have matching **taints**. |
| `serviceAccountName` | The identity (ServiceAccount) the pod uses to call the Kubernetes API. RBAC applies to it. |
| `securityContext` (pod) | Security defaults for **all containers** plus volumes: `runAsUser`, `runAsNonRoot`, `fsGroup`, `seccompProfile`. |
| `terminationGracePeriodSeconds` | How long Kubernetes waits after SIGTERM before sending SIGKILL (default 30s). |
| `hostNetwork` | If `true`, the pod uses the **node's** network (node IP and ports) instead of its own pod IP. |
| `dnsPolicy` | How DNS is set up for the pod: `ClusterFirst` (default, uses CoreDNS), `Default` (inherits the node's DNS), `ClusterFirstWithHostNet` (for hostNetwork pods), `None` (you supply `dnsConfig`). |

### Differences between fields that are easy to confuse

| A vs B | Difference |
|--------|-----------|
| `command` vs `args` | `command` replaces the image's ENTRYPOINT (the program). `args` replaces CMD (its arguments). Set only `args` to keep the image's program and change its flags. |
| `env` vs `envFrom` | `env` picks variables **one at a time** (you can rename keys). `envFrom` imports **every key** from a ConfigMap or Secret in bulk (an optional `prefix` is added). |
| `volumes` vs `volumeMounts` | `volumes` (pod level) says **what** storage exists. `volumeMounts` (container level) says **where** each container sees it. You need both. |
| `requests` vs `limits` | `requests` is what the scheduler reserves for the pod (minimum). `limits` is the hard ceiling at runtime (maximum). |
| `livenessProbe` vs `readinessProbe` vs `startupProbe` | Liveness failure means **restart**. Readiness failure means **no traffic** (no restart). Startup **pauses** the other two until the app is up. |
| `postStart` vs `preStop` | `postStart` runs once after the container starts. `preStop` runs before the container is stopped, so the app can drain. |
| `containers` vs `initContainers` | Init containers run **sequentially, to completion, first**. App containers run **in parallel, long-running, after**. |
| `securityContext` (pod) vs (container) | The pod-level one is the default for all containers and also controls volume ownership (`fsGroup`). The container-level one **overrides** it for a single container and adds container-only settings (`capabilities`, `privileged`, `readOnlyRootFilesystem`). |
| `nodeSelector` vs `affinity` | `nodeSelector` is exact label match only, and always hard. `affinity` supports operators (`In`, `NotIn`, `Exists`), soft preferences with weights, and pod-to-pod rules. |
| `affinity` vs `tolerations` | Affinity **pulls** a pod **toward** certain nodes. A toleration only **allows** a pod onto a tainted node and doesn't force it there. Use both for dedicated nodes. |
| `restartPolicy` vs `livenessProbe` | `restartPolicy` decides what happens **after a container exits**. A liveness probe **kills** a container that is still running but stuck, and then `restartPolicy` applies. |
| `terminationGracePeriodSeconds` vs `preStop` | `preStop` is **what** runs at shutdown. The grace period is the **total time budget** for preStop plus the app's SIGTERM handling, before SIGKILL. |
| `hostNetwork` vs `ports` | `ports` describes ports on the **pod's own IP**. With `hostNetwork: true` those ports are opened directly **on the node**, so two such pods can't use the same port on one node. |
| `serviceAccountName` vs `imagePullSecrets` | The ServiceAccount is the pod's identity **for the Kubernetes API**. `imagePullSecrets` are credentials **for the container registry**. |

## Multi-container patterns

| Pattern | Example |
|---------|---------|
| **Sidecar** | Log shipper, service-mesh proxy (Envoy) |
| **Ambassador** | Local proxy to an external DB |
| **Adapter** | Converts app metrics to Prometheus format |
| **Init container** | Wait for a DB, run migrations (see topic 10) |

**Why these patterns work.** All containers in a pod share the same **network** (`localhost`)
and can share **volumes**. They are scheduled on the same node and start and stop together.
So you can split one job into a **main app container** plus small **helper containers**.
Each helper does one thing well, is reusable across many apps, and keeps the main image clean.
The three patterns differ by **which direction the helper faces**:

```
            SIDECAR                      AMBASSADOR                      ADAPTER
   extends/enhances the app      proxies the app's OUTGOING      normalizes the app's OUTPUT
                                 calls to the outside world      for the outside world
 ┌──────────── Pod ──────────┐ ┌──────────── Pod ──────────┐ ┌──────────── Pod ──────────┐
 │ [app] ──writes──► vol     │ │ [app] ──localhost:6379──► │ │ [app] ── custom format ──►│
 │            [sidecar] ◄─┘  │ │        [ambassador] ──────┼─┼─► DB  [adapter] ─standard─┼─► Prometheus
 │      ships logs out ──────┼─► │   (routing, retries, TLS) │ │      format on :9100      │
 └───────────────────────────┘ └───────────────────────────┘ └───────────────────────────┘
```

### 1. Sidecar: "add a feature next to the app"
**Definition:** A helper container that runs **alongside** the main container for its whole
life and **extends or enhances** it **without changing the app's code**.

- **How it works:** It usually shares a volume (reads the files the app writes) or sits on the
  network path (intercepts traffic through `localhost` or iptables).
- **Typical examples:**
  - **Log shipper** (Fluent Bit, Vector): the app writes logs to a shared `emptyDir`, and the sidecar tails them and ships them to Loki or Elasticsearch.
  - **Service-mesh proxy** (Envoy in Istio, linkerd-proxy): it intercepts all of the pod's in and out traffic to add mTLS, retries, metrics and tracing.
  - **Config or secret reloader** (Vault Agent, git-sync): it keeps fetching fresh config or secrets into a shared volume.
- **Key point:** The app doesn't know the sidecar exists. The sidecar adds capabilities **around** the app.
- **Modern Kubernetes (v1.29+):** declare it as an `initContainer` with `restartPolicy: Always` (a **native sidecar**). It then starts **before** the app, stops **after** it, and doesn't block Jobs from completing (see topic 10).
- **Example:** `multi-container-pod.yaml`

### 2. Ambassador: "a local representative for remote services"
**Definition:** A specialized sidecar that acts as a **proxy for the app's outgoing connections**.
The app always talks to `localhost`, and the ambassador decides **where and how** that
traffic actually reaches the outside world.

- **How it works:** The app connects to `localhost:6379` as if the database were local. The
  ambassador accepts that connection and forwards it to the real backend, which could be one
  server, a sharded cluster, or a different host per environment.
- **Typical examples:**
  - A DB proxy: **Cloud SQL Auth Proxy** (handles IAM auth and TLS to Google Cloud SQL), **PgBouncer** (connection pooling), **twemproxy** (Redis/Memcached sharding).
  - Picking a different backend per environment: dev, staging and prod all use `localhost:5432` in the app config, and only the ambassador's config changes.
  - Adding TLS, auth, retries, circuit breaking or rate limiting to an app that has none of these.
- **Key point:** It **simplifies the app's view of the outside world**. The app code stays the
  same; connection logic (discovery, sharding, auth, TLS) moves into the ambassador.
- **Example:** `pod-ambassador.yaml`

### 3. Adapter: "translate the app's output into a standard format"
**Definition:** A helper container that **converts the app's output** (metrics, logs, status)
**into a standard format** that the rest of the platform expects.

- **How it works:** It reads the app's native output (a status endpoint, a file, a custom log
  format) and **re-exposes it in a common interface**. The most common case is a Prometheus
  `/metrics` endpoint.
- **Typical examples:**
  - **Prometheus exporters**: `redis_exporter`, `mysqld_exporter`, `nginx-prometheus-exporter`. Each reads a native stats page and serves Prometheus metrics.
  - Converting a legacy app's custom log lines into structured JSON.
  - Normalizing health or status output so every app in the company looks the same to monitoring.
- **Key point:** Many different apps with different formats each get an adapter, so **monitoring
  sees one uniform interface**. It's the opposite direction from an ambassador: an adapter
  standardizes what goes **out of** the app to observers, while an ambassador simplifies what the app **calls**.
- **Example:** `pod-adapter.yaml`

### Sidecar vs ambassador vs adapter

| | Sidecar | Ambassador | Adapter |
|--|---------|-----------|---------|
| **Purpose** | Extend or enhance the app | Proxy the app's **outbound** connections | Standardize the app's **output** |
| **Traffic direction** | Any (often observes or wraps the app) | App → outside world | App → monitoring/consumers |
| **The app sees it as** | Invisible | "The service is on localhost" | Invisible (it just reads the app) |
| **Who benefits** | The app gets new features | The app gets simpler connectivity | The platform gets a uniform interface |
| **Common examples** | Fluent Bit, Envoy, Vault Agent, git-sync | Cloud SQL Proxy, PgBouncer, twemproxy | Prometheus exporters, log formatters |

> Ambassador and adapter are **special kinds of sidecar**: technically, all three are just extra
> containers in the same pod. The name tells you the **role** the helper plays.

### When to use a helper container, and when not to
- **Use one** when the helper must share the app's lifecycle, network or files, and you want
  to reuse it across many apps without changing their code.
- **Don't** put two independent apps in one pod just to "group" them. They can't scale
  separately, and if one crashes it affects the other. Use separate Deployments and Services for those.
- **Cost:** each helper adds CPU and memory to **every replica**. Give helpers small `resources` requests and limits.

## Static pods
The kubelet runs YAML placed in `/etc/kubernetes/manifests` with no API server involved.
The API server shows a read-only "mirror pod" for each. This is how kubeadm runs the control plane.

## Files in this folder

| File | Shows |
|------|-------|
| `pod.yaml` | Minimal pod |
| `pod-full.yaml` | Most commonly used fields, annotated |
| `pod-command-args.yaml` | command/args override |
| `pod-env.yaml` | env vars and the Downward API |
| `multi-container-pod.yaml` | Sidecar sharing a volume |
| `pod-ambassador.yaml` | Ambassador proxying localhost to a Redis Service |
| `pod-adapter.yaml` | Adapter converting custom stats to Prometheus format |
| `pod-lifecycle-hooks.yaml` | postStart/preStop |

## Commands

```bash
kubectl apply -f pod.yaml
kubectl get pods -o wide --show-labels
kubectl describe pod nginx            # look at Events at the bottom
kubectl logs nginx [-f] [--previous] [-c container]
kubectl exec -it nginx -- sh
kubectl port-forward pod/nginx 8080:80
kubectl get pod nginx -o yaml
kubectl get pod nginx -o jsonpath='{.status.podIP}'
kubectl delete pod nginx [--grace-period=0 --force]
kubectl run nginx --image=nginx --dry-run=client -o yaml > pod.yaml   # generate YAML
```

## Gotchas
- You can't edit most of a running pod's spec. Delete it and recreate it. (Image, and resources via in-place resize in v1.33+, are exceptions.)
- `latest` tag + `IfNotPresent` = surprises. Pin tags.
- PID 1 must handle SIGTERM, or shutdown takes the full grace period.

## Interview questions
- Why pods and not just containers? (Shared network and storage for tightly coupled processes.)
- How do two containers in a pod communicate? (`localhost`, a shared volume, or a shared process namespace if enabled.)
- What is the `pause` container? (It holds the pod's network namespace. App containers join it.)
