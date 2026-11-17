# 00 - Setup

## Theory

To practice you need a cluster and a client.

| Tool | What it is | When to use |
|------|------------|-------------|
| **kubectl** | CLI that talks to the API server | Always |
| **kind** | Kubernetes IN Docker; each node is a container | Fast, multi-node, CI-friendly. Recommended here |
| **minikube** | Single-node cluster in a VM or container | Has addons (ingress, metrics-server) one command away |
| **k3d / k3s** | Lightweight Kubernetes | Low-resource machines |
| **Docker Desktop** | Built-in single-node cluster | Simplest on Mac |

### kubeconfig and contexts

`kubectl` reads `~/.kube/config` (or `$KUBECONFIG`). It has three lists:

- **clusters**: API server URL and CA certificate
- **users**: credentials (certs, tokens, exec plugins)
- **contexts**: a (cluster + user + default namespace) triple

```bash
kubectl config get-contexts
kubectl config use-context kind-learn
kubectl config set-context --current --namespace=dev
kubectl config view --minify
```

## Install (macOS)

```bash
brew install kubectl kind helm kustomize
```

## Create a multi-node cluster

```bash
kind create cluster --name learn --config kind-cluster.yaml
kubectl get nodes -o wide
```

## Useful addons

```bash
# metrics-server (needed for kubectl top and HPA)
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
# on kind, add --kubelet-insecure-tls to the metrics-server container args:
kubectl patch deploy metrics-server -n kube-system --type=json \
  -p='[{"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--kubelet-insecure-tls"}]'

# ingress-nginx for kind
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml
```

## Productivity

```bash
alias k=kubectl
source <(kubectl completion zsh)
export do="--dry-run=client -o yaml"     # k create deploy x --image=nginx $do
```

Also useful: `k9s` (terminal UI), `kubectx`/`kubens` (switch context/namespace), `stern` (multi-pod logs).

## Delete the cluster

```bash
kind delete cluster --name learn
```
