# 18-k8s.sh: Kubernetes aliases and functions
# k: kubectl wrapper with namespace support
# k.ns, k.ctx: Namespace and context management
# k.get-secrets: Decode deployment secrets
# k.list-pods-in-deployment: List pods for a deployment
# Sources: kubectl completion and per-cluster kube aliases

# https://kubernetes.io/docs/reference/kubectl/cheatsheet/
# https://opensource.com/article/20/2/kubectl-helm-commands

test -f "$HOME"/.kubectl-completion-bash && . "$HOME"/.kubectl-completion-bash

k() {
  kubectl ${KUBE_NAMESPACE:+-n "$KUBE_NAMESPACE"} "$@"
}
complete -F __start_kubectl k

# permanently save the namespace for all subsequent kubectl commands in that context.
alias k.ns=k_ns
alias k.ctx=k_ctx

k_ns() {
  test $# -gt 0 || {
    kubectl get ns
    return
  }
  kubectl config set-context --current --namespace "$@"
}

k_ctx() {
  test $# -gt 0 || {
    kubectl config get-contexts
    return
  }
  kubectl config use-context "$@"
}

k_getSecrets() {
  test $# -eq 0 && {
    echo "Missing deployment name" && k get deployments
    return 1
  }
  local deployment="$1"; shift
  kubectl get secrets "$deployment" -o jsonpath="{.data['$(echo "secrets.properties" | sed -E 's/\./\\./g')']]" \
  | base64 --decode
}
alias k.get-secrets='k_getSecrets'

# https://stackoverflow.com/a/73525759/299109
k_list_pods_in_deployment() {
  test $# -eq 0 && {
    echo "Missing deployment name" && kubectl get deployments
    return 1
  }
  local deployment="$1"; shift
  local replicaSet="$(kubectl describe deployment $deployment \
    | grep '^NewReplicaSet' \
    | awk '{print $2}'
  )"

  local podHashLabel="$(kubectl get rs $replicaSet \
    -o jsonpath='{.metadata.labels.pod-template-hash}'
  )"

  kubectl get pods -l pod-template-hash=$podHashLabel --show-labels \
    | tail -n +2 | awk '{print $1}'

}
alias k.list-pods-in-deployment=k_list_pods_in_deployment

# Source per-cluster kube aliases if they exist
for kube_aliases in ~/.kube/aliases-*; do
  . "$kube_aliases"
done

# kubectl create configmap my-file.sh --from-file=my-file.sh
