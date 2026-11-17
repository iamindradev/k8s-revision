#!/usr/bin/env bash
# Walk through the components of a running cluster.
set -x
kubectl get nodes -o wide
kubectl get pods -n kube-system -o wide
kubectl describe node "$(kubectl get nodes -o jsonpath='{.items[0].metadata.name}')" | sed -n '/Capacity/,/Events/p'
kubectl get componentstatuses 2>/dev/null || true   # deprecated, but still informative
kubectl get --raw='/readyz?verbose'
kubectl api-resources --namespaced=true | head -30
