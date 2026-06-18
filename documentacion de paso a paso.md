# Documentación Paso a Paso

Esta documentación registra de forma incremental todas las configuraciones, dockerizaciones y pipelines implementados en el proyecto **Prueba 3 DevOps**.

---

## 1. Inicialización del Monorepositorio

**Problema:** El directorio `/home/asaro/Developer/Prueba 3 Devops` no era un repositorio Git. Además, las subcarpetas (`front_despacho`, `back-Ventas_SpringBoot`, `back-Despachos_SpringBoot`) tenían cada una su propio `.git` interno (eran repositorios independientes).

**Solución:**
1. Se ejecutó `git init` en la raíz del proyecto.
2. Se eliminaron los directorios `.git` internos de las tres subcarpetas para unificar todo en un solo monorepositorio.
3. Se agregaron todos los archivos al staging area con `git add .`.
4. Se realizó el primer commit: `"Initial commit: unified front-end and back-end services"`.
5. Se configuró el remote `origin` apuntando a `https://github.com/ingdaidai/prueba3devops.git`.
6. Se realizó el push inicial a la rama `main`.

**Comandos ejecutados:**
```bash
git init
rm -rf front_despacho/.git back-Ventas_SpringBoot/.git back-Despachos_SpringBoot/.git
git add .
git commit -m "Initial commit: unified front-end and back-end services"
git remote add origin https://github.com/ingdaidai/prueba3devops.git
git branch -M main
git push -u origin main
```

---

## 2. Dockerización del Backend Despachos

**Archivo creado:** `back-Despachos_SpringBoot/Springboot-API-REST-DESPACHO/Dockerfile`

**Descripción:** Dockerfile multi-stage que:
- **Stage 1 (build):** Usa `maven:3.9-eclipse-temurin-17` para compilar el proyecto Spring Boot con Maven, descargando dependencias primero (cache de capas) y luego empaquetando el JAR sin ejecutar tests.
- **Stage 2 (runtime):** Usa `eclipse-temurin:17-jre-alpine` como imagen ligera de producción, copiando solo el JAR compilado.
- **Puerto expuesto:** `8081` (configurado en `application.properties`).

---

## 3. Dockerización del Backend Ventas

**Archivo creado:** `back-Ventas_SpringBoot/Springboot-API-REST/Dockerfile`

**Descripción:** Dockerfile multi-stage idéntico en estructura al de Despachos:
- **Stage 1 (build):** Compilación con Maven + Java 17.
- **Stage 2 (runtime):** JRE Alpine ligero.
- **Puerto expuesto:** `8080` (puerto por defecto de Spring Boot).

---

## 4. Dockerización del Frontend

**Archivos creados:**
- `front_despacho/Dockerfile`
- `front_despacho/nginx.conf`

**Descripción:**
- **Dockerfile multi-stage:**
  - **Stage 1 (build):** Usa `node:20-alpine` para instalar dependencias con `npm ci` y compilar la aplicación React/Vite con `npm run build`.
  - **Stage 2 (runtime):** Usa `nginx:1.27-alpine` para servir los archivos estáticos generados en `/dist`.
- **nginx.conf:** Configuración personalizada de Nginx que:
  - Sirve la SPA de React con `try_files $uri $uri/ /index.html` para soportar React Router.
  - Habilita compresión Gzip.
  - Configura cache de assets estáticos por 1 año.

---

## 5. Docker Compose para Despliegue del Frontend en EC2

**Archivo creado:** `front_despacho/docker-compose.yml`

**Descripción:** Archivo Docker Compose simple para desplegar el frontend de forma independiente en la instancia EC2 del frontend. Mapea el puerto 80 del contenedor al puerto 80 del host.

---

## 6. Docker Compose Global para Desarrollo Local

**Archivo creado:** `docker-compose.yml` (raíz del proyecto)

**Descripción:** Docker Compose que levanta todo el stack para desarrollo local:
- **mysql:** Contenedor MySQL 8.0 con healthcheck, volumen persistente y variables de entorno desde `.env`.
- **backend-ventas:** Construye desde el Dockerfile de Ventas, se conecta a MySQL, expone puerto 8080.
- **backend-despachos:** Construye desde el Dockerfile de Despachos, se conecta a MySQL, expone puerto 8081.
- **frontend:** Construye el frontend con Nginx, expone puerto 3000 (mapeado al 80 interno).

**Uso:**
```bash
cp .env.example .env
# Editar .env con tus valores
docker compose up --build
```

---

## 7. Archivo de Variables de Entorno de Ejemplo

**Archivo creado:** `.env.example`

**Descripción:** Plantilla con todas las variables de entorno necesarias:
- Variables de base de datos: `DB_ENDPOINT`, `DB_PORT`, `DB_NAME`, `DB_USERNAME`, `DB_PASSWORD`.
- Variables de AWS/ECR: `AWS_REGION`, `AWS_ACCOUNT_ID`, nombres de repositorios ECR.

---

## 8. Pipeline CI/CD Backend Despachos

**Archivo creado:** `.github/workflows/backend-despacho.yml`

**Descripción:** Pipeline de GitHub Actions que se dispara automáticamente al hacer push a `main` cuando hay cambios en `back-Despachos_SpringBoot/**`. Pasos:
1. Checkout del repositorio.
2. Configuración de credenciales AWS (access key, secret key, session token).
3. Login en Amazon ECR.
4. Build de la imagen Docker y push a ECR.
5. Obtención de secretos desde Doppler (dirección IP del servidor).
6. Conexión SSH a la EC2 de despachos para:
   - Instalar AWS CLI y Docker si no existen.
   - Login en ECR desde la EC2.
   - Detener y eliminar el contenedor anterior.
   - Pull de la nueva imagen.
   - Ejecutar el nuevo contenedor con las variables de entorno de la BD.
   - Limpieza de imágenes sin usar.

---

## 9. Pipeline CI/CD Backend Ventas

**Archivo creado:** `.github/workflows/backend-ventas.yml`

**Descripción:** Pipeline análogo al de Despachos. Se dispara al detectar cambios en `back-Ventas_SpringBoot/**`. Usa la misma estrategia: build → push a ECR → deploy por SSH a EC2, pero apuntando al repositorio ECR `ventas-api` y desplegando en la EC2 de ventas (puerto 8080).

---

## 10. Pipeline CI/CD Frontend

**Archivo creado:** `.github/workflows/frontend.yml`

**Descripción:** Pipeline que se dispara al detectar cambios en `front_despacho/**`. Pasos:
1. Build de la imagen Docker del frontend (Node build + Nginx).
2. Push de la imagen a Amazon ECR (`frontend-despacho`).
3. Deploy por SSH a la EC2 del frontend:
   - Login en ECR.
   - Detener contenedor anterior.
   - Pull de la nueva imagen.
   - Ejecutar el contenedor mapeando puerto 80.
   - Limpieza de imágenes.

---

## 11. Limpieza de Workflows Antiguos

**Directorios eliminados:**
- `back-Despachos_SpringBoot/.github/`
- `back-Ventas_SpringBoot/.github/`
- `front_despacho/.github/`

**Razón:** Los workflows antiguos estaban dentro de las subcarpetas y no serían detectados por GitHub Actions. Fueron reemplazados por los nuevos workflows en `.github/workflows/` en la raíz del monorepositorio.

---

## 12. Archivo .gitignore

**Archivo creado:** `.gitignore` (raíz)

**Descripción:** Ignora archivos `.env`, `.DS_Store`, directorios de IDE, `node_modules/`, `target/` de Maven, y archivos `docker-compose.override.yml`.

---

## Estado del Proyecto

- [x] Repositorio Git inicializado y unificado en monorepositorio
- [x] Dockerización de Backend Despachos (`Dockerfile`)
- [x] Dockerización de Backend Ventas (`Dockerfile`)
- [x] Dockerización de Frontend (`Dockerfile` + `nginx.conf`)
- [x] Docker Compose para despliegue frontend en EC2
- [x] Docker Compose global para desarrollo local
- [x] Variables de entorno de ejemplo (`.env.example`)
- [x] Pipeline CI/CD Backend Despachos (`.github/workflows/backend-despacho.yml`)
- [x] Pipeline CI/CD Backend Ventas (`.github/workflows/backend-ventas.yml`)
- [x] Pipeline CI/CD Frontend (`.github/workflows/frontend.yml`)
- [x] Eliminación de workflows antiguos en subcarpetas
- [x] Archivo `.gitignore` en la raíz

---

## Secretos Requeridos en GitHub

Para que los pipelines funcionen correctamente, debes configurar los siguientes secretos en tu repositorio de GitHub (`Settings → Secrets and variables → Actions`):

| Secreto | Descripción |
|---------|-------------|
| `AWS_ACCESS_KEY_ID` | Access Key de AWS Academy |
| `AWS_SECRET_ACCESS_KEY` | Secret Key de AWS Academy |
| `AWS_SESSION_TOKEN` | Session Token de AWS Academy (Learned Lab) |
| `DOPPLER_TOKEN` | Token de acceso a Doppler para secretos |
| `DB_ENDPOINT` | Endpoint de la base de datos MySQL (RDS) |
| `DB_PORT` | Puerto de la base de datos (generalmente `3306`) |
| `DB_NAME` | Nombre de la base de datos |
| `DB_USERNAME` | Usuario de la base de datos |
| `DB_PASSWORD` | Contraseña de la base de datos |
| `EC2_USERNAME` | Usuario SSH para backends (generalmente `ubuntu`) |
| `SSH_KEY_CITT` | Clave SSH privada para backends |
| `EC2_SSH_PORT` | Puerto SSH para backends (generalmente `22`) |
| `USERNAME` | Usuario SSH para el servidor frontend |
| `EC2_KEY` | Clave SSH privada para el servidor frontend |
| `PORT` | Puerto SSH para el servidor frontend |

## Repositorios ECR Requeridos

Debes crear los siguientes repositorios en Amazon ECR (en la región `us-east-1`):

1. `despachos-api`
2. `ventas-api`
3. `frontend-despacho`

**Comando para crearlos:**
```bash
aws ecr create-repository --repository-name despachos-api --region us-east-1
aws ecr create-repository --repository-name ventas-api --region us-east-1
aws ecr create-repository --repository-name frontend-despacho --region us-east-1
```
