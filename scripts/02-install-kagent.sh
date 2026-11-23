#!/usr/bin/env bash
# Instala os CRDs e o kagent via Helm (charts OCI), com versão fixada.
source "$(dirname "$0")/lib.sh"

require_cmd helm
require_api_key
use_cluster_context

step "Instalando CRDs do kagent ${KAGENT_VERSION}"
helm upgrade --install kagent-crds oci://ghcr.io/kagent-dev/kagent/helm/kagent-crds \
  --version "${KAGENT_VERSION}" \
  --namespace "${KAGENT_NAMESPACE}" --create-namespace \
  --wait

step "Instalando kagent ${KAGENT_VERSION} (provedor padrão: ${LLM_PROVIDER})"
# A chave vai por variável de ambiente, não fica no histórico do shell.
helm upgrade --install kagent oci://ghcr.io/kagent-dev/kagent/helm/kagent \
  --version "${KAGENT_VERSION}" \
  --namespace "${KAGENT_NAMESPACE}" \
  --values "${ROOT_DIR}/k8s/kagent/helm-values.yaml" \
  --set "providers.default=${HELM_PROVIDER_KEY}" \
  --set-string "providers.${HELM_PROVIDER_KEY}.apiKey=${LLM_API_KEY}" \
  --wait --timeout 10m

step "Aguardando os componentes do kagent"
kubectl -n "${KAGENT_NAMESPACE}" rollout status deployment/kagent-controller --timeout=300s
kubectl -n "${KAGENT_NAMESPACE}" get pods
ok "kagent instalado"

echo
echo "CRDs registrados:"
kubectl get crd -o name | grep kagent.dev || true
