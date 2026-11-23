#!/usr/bin/env bash
# Constrói a imagem do MCP Server e carrega no kind (sem precisar de registry).
source "$(dirname "$0")/lib.sh"

require_cmd docker
require_cmd kind

step "Construindo imagem ${IMAGE}"
DOCKER_BUILDKIT=1 docker build -t "${IMAGE}" "${ROOT_DIR}/service-catalog"

step "Carregando imagem no cluster kind '${CLUSTER_NAME}'"
kind load docker-image "${IMAGE}" --name "${CLUSTER_NAME}"
ok "Imagem disponível nos nós do cluster"
