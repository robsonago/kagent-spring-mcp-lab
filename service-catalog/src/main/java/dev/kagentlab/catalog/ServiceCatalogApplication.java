package dev.kagentlab.catalog;

import java.time.Clock;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.boot.context.properties.ConfigurationPropertiesScan;
import org.springframework.context.annotation.Bean;

@SpringBootApplication
@ConfigurationPropertiesScan
public class ServiceCatalogApplication {

    public static void main(String[] args) {
        SpringApplication.run(ServiceCatalogApplication.class, args);
    }

    /** Relógio injetável, facilita testar a regra de congelamento de mudanças. */
    @Bean
    Clock clock() {
        return Clock.systemDefaultZone();
    }
}
