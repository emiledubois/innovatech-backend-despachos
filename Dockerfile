# Etapa 1: Build 
FROM eclipse-temurin:17-jdk-alpine AS builder
WORKDIR /app
 

COPY pom.xml .
COPY .mvn .mvn
COPY mvnw .
RUN chmod +x mvnw && ./mvnw dependency:go-offline -q
 
# Copiar código fuente y compilar
COPY src ./src
RUN ./mvnw package -DskipTests -q
 
# Etapa 2: Runtime 
FROM eclipse-temurin:17-jre-alpine AS runtime
WORKDIR /app
 
# Crear usuario no-root 
RUN addgroup -S appgroup && adduser -S appuser -G appgroup
 
# Copiar sólo el JAR generado
COPY --from=builder /app/target/*.jar app.jar
 
# Cambiar propietario y usar usuario no-root
RUN chown appuser:appgroup app.jar
USER appuser
 
# Puerto expuesto
EXPOSE 8081
 
# Variables de entorno
ENV DB_ENDPOINT=localhost \
    DB_PORT=3306 \
    DB_NAME=despachos_db \
    DB_USERNAME=root \
    DB_PASSWORD=root
 
ENTRYPOINT ["java", "-jar", "app.jar"]
