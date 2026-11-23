package dev.kagentlab.catalog.domain;

import java.util.List;

/**
 * Objetos de resposta das tools MCP. São serializados em JSON e entregues ao LLM,
 * então os nomes dos campos devem ser autoexplicativos.
 */
public final class Views {

    private Views() {
    }

    public record ServiceSummary(String name, String namespace, String team, String tier, String description) {
    }

    public record OwnerInfo(String service, String team, String onCall, String slackChannel, String escalation) {
    }

    public record RunbookResult(String service, String requestedSymptom, boolean exactMatch,
                                List<CatalogProperties.Runbook> runbooks) {
    }

    public record FreezeStatus(String service, String tier, String today, boolean deployAllowed,
                               String activeFreeze, String reason, String recommendation) {
    }
}
