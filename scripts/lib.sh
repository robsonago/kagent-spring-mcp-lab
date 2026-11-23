#!/usr/bin/env bash
# Funções e variáveis compartilhadas pelos scripts. Não execute diretamente.
# shellcheck disable=SC2034  # variáveis usadas pelos scripts que fazem source deste arquivo
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Carrega o .env (se existir) sem sobrescrever variáveis já exportadas no shell.
if [[ -f "${ROOT_DIR}/.env" ]]; then
  while IFS='=' read -r key value; do
    [[ -z "${key}" || "${key}" =~ ^[[:space:]]*# ]] && continue
    key="$(echo "${key}" | xargs)"
    value="${value%\"}"; value="${value#\"}"
    if [[ -z "${!key:-}" ]]; then export "${key}=${value}"; fi
  done < "${ROOT_DIR}/.env"
fi

CLUSTER_NAME="${CLUSTER_NAME:-kagent-lab}"
KAGENT_VERSION="${KAGENT_VERSION:-0.10.6}"
KAGENT_NAMESPACE="kagent"
LLM_PROVIDER="$(echo "${LLM_PROVIDER:-openai}" | tr '[:upper:]' '[:lower:]')"
IMAGE="service-catalog:0.1.0"
AGENT_NAME="sre-triage-agent"

case "${LLM_PROVIDER}" in
  openai)
    LLM_API_KEY="${OPENAI_API_KEY:-}"
    LLM_MODEL="${LLM_MODEL:-gpt-4.1-mini}"
    KAGENT_PROVIDER_ENUM="OpenAI"
    KAGENT_PROVIDER_BLOCK="openAI: {}"
    HELM_PROVIDER_KEY="openAI"
    ;;
  anthropic)
    LLM_API_KEY="${ANTHROPIC_API_KEY:-}"
    LLM_MODEL="${LLM_MODEL:-claude-sonnet-4-6}"
    KAGENT_PROVIDER_ENUM="Anthropic"
    KAGENT_PROVIDER_BLOCK="anthropic: {}"
    HELM_PROVIDER_KEY="anthropic"
    ;;
  *)
    echo "LLM_PROVIDER inválido: '${LLM_PROVIDER}'. Use openai ou anthropic." >&2
    exit 1
    ;;
esac

if [[ -t 1 ]]; then
  BOLD=$'\e[1m'; GREEN=$'\e[32m'; YELLOW=$'\e[33m'; RED=$'\e[31m'; RESET=$'\e[0m'
else
  BOLD=""; GREEN=""; YELLOW=""; RED=""; RESET=""
fi

step() { echo; echo "${BOLD}==> $*${RESET}"; }
ok()   { echo "${GREEN}✔ $*${RESET}"; }
warn() { echo "${YELLOW}⚠ $*${RESET}"; }
fail() { echo "${RED}✖ $*${RESET}" >&2; exit 1; }

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || fail "Comando '$1' não encontrado. Veja a seção Pré-requisitos do README."
}

require_api_key() {
  if [[ -z "${LLM_API_KEY}" ]]; then
    local var="OPENAI_API_KEY"
    [[ "${LLM_PROVIDER}" == "anthropic" ]] && var="ANTHROPIC_API_KEY"
    fail "Defina ${var} (no shell ou no arquivo .env). Provedor atual: ${LLM_PROVIDER}."
  fi
}

use_cluster_context() {
  kubectl config use-context "kind-${CLUSTER_NAME}" >/dev/null 2>&1 \
    || fail "Contexto kind-${CLUSTER_NAME} não encontrado. Rode 'make cluster' primeiro."
}

# Inicia um port-forward em background e garante que ele morre quando o script terminar.
PF_PIDS=()
cleanup_port_forwards() {
  for pid in "${PF_PIDS[@]:-}"; do
    [[ -n "${pid}" ]] && kill "${pid}" >/dev/null 2>&1 || true
  done
}
trap cleanup_port_forwards EXIT

port_forward() {
  local namespace="$1" target="$2" ports="$3"
  kubectl -n "${namespace}" port-forward "${target}" "${ports}" >/dev/null 2>&1 &
  PF_PIDS+=("$!")
  local local_port="${ports%%:*}"
  for _ in $(seq 1 30); do
    if (echo >"/dev/tcp/127.0.0.1/${local_port}") >/dev/null 2>&1; then return 0; fi
    sleep 1
  done
  fail "port-forward para ${namespace}/${target} (${ports}) não respondeu."
}
