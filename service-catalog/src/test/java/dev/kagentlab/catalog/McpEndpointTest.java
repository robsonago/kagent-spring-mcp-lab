package dev.kagentlab.catalog;

import static org.assertj.core.api.Assertions.assertThat;

import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.test.context.SpringBootTest;

/**
 * Sobe a aplicação numa porta aleatória e conversa com o endpoint /mcp
 * exatamente como o kagent faz (JSON-RPC sobre Streamable HTTP).
 */
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
class McpEndpointTest {

    @Value("${local.server.port}")
    int port;

    private final HttpClient http = HttpClient.newHttpClient();

    private HttpResponse<String> rpc(String body) throws Exception {
        HttpRequest request = HttpRequest.newBuilder(URI.create("http://localhost:" + port + "/mcp"))
                .header("Content-Type", "application/json")
                .header("Accept", "application/json, text/event-stream")
                .POST(HttpRequest.BodyPublishers.ofString(body))
                .build();
        return http.send(request, HttpResponse.BodyHandlers.ofString());
    }

    @Test
    void listaAsToolsDoCatalogo() throws Exception {
        HttpResponse<String> response = rpc("""
                {"jsonrpc":"2.0","id":1,"method":"tools/list","params":{}}
                """);

        assertThat(response.statusCode()).isEqualTo(200);
        assertThat(response.body())
                .contains("list_services", "get_service_owner", "get_runbook", "check_change_freeze");
    }

    @Test
    void executaUmaTool() throws Exception {
        HttpResponse<String> response = rpc("""
                {"jsonrpc":"2.0","id":2,"method":"tools/call",
                 "params":{"name":"get_service_owner","arguments":{"service":"checkout-api"}}}
                """);

        assertThat(response.statusCode()).isEqualTo(200);
        assertThat(response.body()).contains("payments", "#payments-oncall");
    }
}
