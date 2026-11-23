#!/usr/bin/env bash
# Verifica ferramentas e configuração antes de começar.
source "$(dirname "$0")/lib.sh"

step "Verificando pré-requisitos"

for cmd in docker kind kubectl helm curl; do
  require_cmd "${cmd}"
  ok "${cmd} encontrado"
done

docker info >/dev/null 2>&1 || fail "O Docker está instalado, mas o daemon não responde. Inicie o Docker Desktop/daemon."
ok "Docker daemon respondendo"

if command -v jq >/dev/null 2>&1; then ok "jq encontrado (opcional)"; else warn "jq não encontrado (opcional, deixa a saída dos testes mais legível)"; fi
if command -v kagent >/dev/null 2>&1; then ok "kagent CLI encontrado (opcional)"; else warn "kagent CLI não encontrado (opcional, os testes usam curl via A2A)"; fi

require_api_key
ok "Chave de API do provedor '${LLM_PROVIDER}' definida (modelo: ${LLM_MODEL})"

# kind + kagent + agentes padrão pedem memória. Abaixo de ~6 GiB os Pods podem ficar Pending.
mem_bytes="$(docker info --format '{{.MemTotal}}' 2>/dev/null || echo 0)"
mem_gib=$(( mem_bytes / 1024 / 1024 / 1024 ))
if (( mem_gib > 0 && mem_gib < 6 )); then
  warn "Docker com ${mem_gib} GiB de memória. Recomendado: 8 GiB ou mais."
else
  ok "Docker com ${mem_gib} GiB de memória"
fi

ok "Tudo pronto."
