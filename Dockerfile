# Etapa 1: Build
FROM eclipse-temurin:17-jdk-alpine AS builder
WORKDIR /app
COPY pom.xml .
COPY .mvn .mvn
COPY mvnw .
RUN chmod +x mvnw && ./mvnw dependency:go-offline -q
COPY src ./src
RUN ./mvnw package -DskipTests -q

# Etapa 2: Runtime
FROM eclipse-temurin:17-jre-alpine AS runtime
WORKDIR /app
RUN addgroup -S appgroup && adduser -S appuser -G appgroup
COPY --from=builder /app/target/*.jar app.jar
RUN chown appuser:appgroup app.jar
USER appuser
EXPOSE 8081
ENV DB_ENDPOINT=localhost \
    DB_PORT=3306 \
    DB_NAME=innovatech \
    DB_USERNAME=appuser \
    DB_PASSWORD=rootpass
ENTRYPOINT ["java", "-jar", "app.jar"]
