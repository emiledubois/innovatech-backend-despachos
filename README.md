# Innovatech Chile – Backend Despachos
> ISY1101 – Introducción a Herramientas DevOps | Evaluación Parcial N°2

## Descripción
Backend de la aplicación de gestión de despachos y ventas de Innovatech Chile. Desarrollado en Spring Boot 3.4 con Java 17, expone una API REST consumida por el frontend. Se conecta a una base de datos MySQL y se despliega en AWS EC2 mediante contenedores Docker.

## Stack Tecnológico
- **Spring Boot 3.4** — framework backend
- **Java 17** — lenguaje de programación
- **MySQL 8.0** — base de datos relacional
- **Docker** — contenedorización con multi-stage build
- **Amazon ECR** — registro de imágenes
- **GitHub Actions** — pipeline CI/CD
- **AWS EC2** — despliegue en la nube

## Arquitectura

```
EC2 Backend (Red privada)
  ┌─────────────────────────────┐
  │  [backend-despachos :8081]  │
  │  [backend-ventas    :8080]  │
  │  [mysql-db          :3306]  │
  │                             │
  │  Red Docker: innovatech_backend
  │  Volumen:    mysql_data     │
  └─────────────────────────────┘
         ↑
  Solo acepta tráfico
  desde SG del Frontend
```

## Endpoints disponibles

| Método | Endpoint | Descripción |
|---|---|---|
| GET | `/api/v1/despachos` | Listar despachos |
| POST | `/api/v1/despachos` | Crear despacho |
| PUT | `/api/v1/despachos/{id}` | Actualizar despacho |
| DELETE | `/api/v1/despachos/{id}` | Eliminar despacho |
| GET | `/api/v1/ventas` | Listar ventas |
| GET | `/swagger-ui.html` | Documentación API |

## Estructura del Proyecto

```
├── src/
│   └── main/
│       ├── java/com/citt/
│       │   ├── controller/       # Controladores REST
│       │   ├── persistence/
│       │   │   └── entity/       # Entidades JPA
│       │   └── config/
│       │       └── CorsConfig.java
│       └── resources/
│           └── application.properties
├── Dockerfile                    # Multi-stage build
├── docker-compose.yml            # Stack completo
├── .github/
│   └── workflows/
│       └── deploy.yml           # Pipeline CI/CD
├── .env.example                 # Variables requeridas
├── .gitignore
└── pom.xml
```

## Dockerfile – Multi-Stage Build

El Dockerfile implementa dos etapas:

1. **Builder**: usa `eclipse-temurin:17-jdk-alpine` para compilar el proyecto con Maven
2. **Runtime**: usa `eclipse-temurin:17-jre-alpine` para ejecutar el JAR compilado

Características de seguridad:
- Usuario no-root (`appuser`) en la etapa de runtime
- Imagen final solo con JRE, sin JDK ni Maven (~180MB vs ~600MB)
- Cache de capas optimizado (pom.xml separado del código fuente)

## docker-compose.yml

Orquesta el stack completo con:

- **mysql-db**: MySQL 8.0 con named volume para persistencia
- **backend-despachos**: API REST en puerto 8081
- **backend-ventas**: API REST en puerto 8080
- **Redes**: `innovatech_backend` para comunicación interna
- **Healthcheck**: el backend espera a que MySQL esté listo antes de iniciar

## Variables de Entorno

Copia `.env.example` a `.env`:

```bash
cp .env.example .env
```

| Variable | Descripción | Ejemplo |
|---|---|---|
| `DB_ENDPOINT` | Host de la base de datos | `mysql-db` (nombre del contenedor) |
| `DB_PORT` | Puerto MySQL | `3306` |
| `DB_NAME` | Nombre de la base de datos | `innovatech` |
| `DB_USERNAME` | Usuario MySQL | `appuser` |
| `DB_PASSWORD` | Contraseña MySQL | `S3cur3P4ss!` |

## Ejecutar Localmente

### Con Docker Compose (recomendado)

```bash
# Copiar variables de entorno
cp .env.example .env
# Editar .env con tus valores

# Levantar el stack completo
docker compose up --build -d

# Ver logs
docker compose logs -f

# Verificar que funciona
curl http://localhost:8081/api/v1/despachos
curl http://localhost:8080/api/v1/ventas

# Detener
docker compose down
```

### Solo el backend (requiere MySQL externo)

```bash
docker build -t innovatech-backend-despachos .

docker run -d \
  --name backend-despachos \
  -p 8081:8081 \
  -e DB_ENDPOINT=localhost \
  -e DB_PORT=3306 \
  -e DB_NAME=innovatech \
  -e DB_USERNAME=appuser \
  -e DB_PASSWORD=S3cur3P4ss! \
  innovatech-backend-despachos
```

## Persistencia de Datos

Se usa **named volume** (`mysql_data`) para la base de datos:

```yaml
volumes:
  mysql_data:
    name: innovatech_mysql_data
```

**¿Por qué named volume y no bind mount?**
- Docker gestiona completamente la ubicación en disco
- Portable entre diferentes sistemas operativos
- Los datos persisten aunque el contenedor se elimine
- No depende de rutas absolutas del host

## Pipeline CI/CD

El pipeline se activa automáticamente con **push en la rama `deploy`**:

```
push → deploy
    ↓
1. Checkout del código
    ↓
2. Configurar credenciales AWS
    ↓
3. Login a Amazon ECR
    ↓
4. Build imagen Docker (multi-stage)
    ↓
5. Push imagen a ECR con tag del commit SHA
    ↓
6. Deploy en EC2 vía SSH
   - docker pull imagen nueva
   - docker stop contenedor anterior
   - docker run contenedor actualizado
```

### Secrets requeridos en GitHub

| Secret | Descripción |
|---|---|
| `AWS_ACCESS_KEY_ID` | Credencial AWS Academy |
| `AWS_SECRET_ACCESS_KEY` | Clave secreta AWS |
| `AWS_SESSION_TOKEN` | Token de sesión temporal |
| `AWS_ACCOUNT_ID` | ID de cuenta AWS (12 dígitos) |
| `EC2_BACKEND_HOST` | IP pública de la EC2 backend |
| `EC2_SSH_KEY` | Contenido completo del archivo .pem |
| `DB_PASSWORD` | Contraseña de MySQL |

## Imágenes en Amazon ECR

```
# Backend Despachos
757001429093.dkr.ecr.us-east-1.amazonaws.com/innovatech-backend-despachos:latest

# Backend Ventas
757001429093.dkr.ecr.us-east-1.amazonaws.com/innovatech-backend-ventas:latest
```

## Security Groups AWS

| Puerto | Protocolo | Origen | Descripción |
|---|---|---|---|
| 22 | TCP | 0.0.0.0/0 | SSH administración |
| 8080 | TCP | 0.0.0.0/0 | API Ventas |
| 8081 | TCP | 0.0.0.0/0 | API Despachos |
| 3306 | TCP | sg-innovatech-backend | MySQL (solo interno) |

## Convención de Commits

```
feat:   nueva funcionalidad
fix:    corrección de bug
docker: cambios en contenedorización
ci:     cambios en pipeline CI/CD
docs:   actualización de documentación
```

## Principios DevOps Aplicados

- **Contenedorización**: imagen reproducible con multi-stage build
- **CI/CD**: despliegue automático sin intervención manual
- **Persistencia**: named volume garantiza continuidad de datos
- **Mínimo privilegio**: usuario no-root en el contenedor
- **Control de versiones**: rama deploy separada de main
- **Infraestructura como código**: docker-compose.yml y workflow en Git
