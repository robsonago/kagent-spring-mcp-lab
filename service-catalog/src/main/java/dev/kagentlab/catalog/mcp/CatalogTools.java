package dev.kagentlab.catalog.mcp;

import java.util.List;

import dev.kagentlab.catalog.domain.Views.FreezeStatus;
import dev.kagentlab.catalog.domain.Views.OwnerInfo;
import dev.kagentlab.catalog.domain.Views.RunbookResult;
import dev.kagentlab.catalog.domain.Views.ServiceSummary;
import dev.kagentlab.catalog.service.CatalogService;

import org.springframework.ai.mcp.annotation.McpTool;
import org.springframework.ai.mcp.annotation.McpToolParam;
import org.springframework.stereotype.Component;

/**
 * Adaptador MCP, cada método vira uma tool descoberta pelo kagent via tools/list.
 * As descrições são o "contrato" que o LLM lê para decidir quando chamar cada tool,
 * então trate-as como documentação de API.
 *
 * Todas são somente leitura (readOnlyHint = true): o agente não altera nada aqui.
 */
@Component
public class CatalogTools {

    private final CatalogService catalog;

    public CatalogTools(CatalogService catalog) {
        this.catalog = catalog;
    }

    @McpTool(name = "list_services",
            description = "Lista os serviços cadastrados no catálogo com namespace Kubernetes, time dono e criticidade (tier). "
                    + "Use para descobrir qual serviço do catálogo corresponde a um Deployment ou Pod.",
            annotations = @McpTool.McpAnnotations(readOnlyHint = true, destructiveHint = false, idempotentHint = true,
                    openWorldHint = false))
    public List<ServiceSummary> listServices(
            @McpToolParam(description = "Filtro opcional pelo nome do time, ex.: payments", required = false) String team) {
        return catalog.listServices(team);
    }

    @McpTool(name = "get_service_owner",
            description = "Retorna o time dono, o on-call atual, o canal de Slack e a política de escalonamento de um serviço. "
                    + "O nome do serviço normalmente é igual ao label app.kubernetes.io/name do Pod.",
            annotations = @McpTool.McpAnnotations(readOnlyHint = true, destructiveHint = false, idempotentHint = true,
                    openWorldHint = false))
    public OwnerInfo getServiceOwner(
            @McpToolParam(description = "Nome do serviço, ex.: checkout-api", required = true) String service) {
        return catalog.getOwner(service);
    }

    @McpTool(name = "get_runbook",
            description = "Retorna o runbook oficial (passos de diagnóstico e correção) de um serviço. "
                    + "Informe o sintoma observado, ex.: CrashLoopBackOff, OOMKilled, latência alta.",
            annotations = @McpTool.McpAnnotations(readOnlyHint = true, destructiveHint = false, idempotentHint = true,
                    openWorldHint = false))
    public RunbookResult getRunbook(
            @McpToolParam(description = "Nome do serviço, ex.: checkout-api", required = true) String service,
            @McpToolParam(description = "Sintoma observado, ex.: CrashLoopBackOff", required = false) String symptom) {
        return catalog.getRunbook(service, symptom);
    }

    @McpTool(name = "check_change_freeze",
            description = "Verifica se existe congelamento de mudanças ativo hoje e se um deploy do serviço é permitido. "
                    + "Consulte antes de recomendar qualquer correção que exija novo deploy.",
            annotations = @McpTool.McpAnnotations(readOnlyHint = true, destructiveHint = false, idempotentHint = true,
                    openWorldHint = false))
    public FreezeStatus checkChangeFreeze(
            @McpToolParam(description = "Nome do serviço, ex.: checkout-api", required = true) String service) {
        return catalog.checkChangeFreeze(service);
    }
}
