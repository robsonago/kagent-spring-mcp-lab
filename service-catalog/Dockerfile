# syntax=docker/dockerfile:1

# ---------- build ----------
FROM maven:3.9-eclipse-temurin-21 AS build
WORKDIR /workspace
COPY pom.xml .
# Cache das dependências entre builds
RUN --mount=type=cache,target=/root/.m2 mvn -B -q dependency:go-offline
COPY src ./src
RUN --mount=type=cache,target=/root/.m2 mvn -B -q package -DskipTests

# ---------- runtime ----------
FROM eclipse-temurin:21-jre-alpine
RUN addgroup -S app && adduser -S app -G app
WORKDIR /app
COPY --from=build /workspace/target/service-catalog.jar app.jar
USER app
EXPOSE 8080
# MaxRAMPercentage respeita o limite de memória do container
ENTRYPOINT ["java", "-XX:MaxRAMPercentage=75", "-jar", "/app/app.jar"]
