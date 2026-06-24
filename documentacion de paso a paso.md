# Documentación Paso a Paso — EP3 DevOps

> **ISY1101 · Introducción a Herramientas DevOps**  
> Tecnología elegida: **AWS ECS Fargate** (monorepositorio con 3 servicios)  
> Repo: `https://github.com/ingdaidai/prueba3devops`

---

## Estado actual del repositorio (código listo ✅)

Todo lo siguiente ya está implementado y commiteado en el repo:

| Componente | Archivo | Estado |
|---|---|---|
| Docker Backend Ventas | `back-Ventas_SpringBoot/Springboot-API-REST/Dockerfile` | ✅ Listo |
| Docker Backend Despachos | `back-Despachos_SpringBoot/Springboot-API-REST-DESPACHO/Dockerfile` | ✅ Listo |
| Docker Frontend (nginx + envsubst) | `front_despacho/Dockerfile` | ✅ Listo |
| nginx reverse proxy template | `front_despacho/nginx.conf` | ✅ Listo |
| Entrypoint runtime vars | `front_despacho/docker-entrypoint.sh` | ✅ Listo |
| Docker Compose local (nombres = ECS) | `docker-compose.yml` | ✅ Listo |
| Variables de entorno ejemplo | `.env.example` | ✅ Listo |
| Pipeline CI/CD Frontend → ECS | `.github/workflows/frontend.yml` | ✅ Listo |
| Pipeline CI/CD Backend Ventas → ECS | `.github/workflows/backend-ventas.yml` | ✅ Listo |
| Pipeline CI/CD Backend Despachos → ECS | `.github/workflows/backend-despacho.yml` | ✅ Listo |
| Task Definitions ECS (referencia) | `ecs/task-def-*.json` | ✅ Listos |
| IPs hardcodeadas eliminadas | 4 componentes JSX | ✅ Corregido |
| `.gitignore` con `.env` excluido | `front_despacho/.gitignore` | ✅ Listo |

---

## Arquitectura objetivo en AWS

```
Internet
    │
    ▼
[ALB — puerto 80, Internet-facing]
    │
    ▼
[ECS Service: frontend-despacho-service]
  └─ Task: nginx (puerto 80)
       │  proxy /api/ventas/*     → ventas-api:8080   (ECS Service Connect)
       └─ proxy /api/despachos/*  → despachos-api:8081 (ECS Service Connect)
                                          │
                                          ▼
                                   [RDS MySQL — privado]
```

---

## Lo que FALTA hacer en AWS (pasos manuales)

### ✅ FASE 0 — Prerequisitos (ya hecho)
- [x] Cuenta AWS Academy activa con Learned Lab iniciado
- [x] AWS CLI instalado y configurado (`aws configure`)
- [x] Docker Desktop corriendo
- [x] Git configurado, repo en GitHub
- [x] Código de frontend y backends con Dockerfiles funcionando
- [x] Decisión tomada: **ECS Fargate**

---

### 🔲 FASE 1 — Crear repositorios ECR

Ejecutar en terminal (con credenciales de Academy activas):

```bash
aws ecr create-repository --repository-name frontend-despacho --region us-east-1
aws ecr create-repository --repository-name ventas-api --region us-east-1
aws ecr create-repository --repository-name despachos-api --region us-east-1
```

- [ ] Creaste repositorio ECR `frontend-despacho` `[ENCARGO IE2]`
- [ ] Creaste repositorio ECR `ventas-api` `[ENCARGO IE2]`
- [ ] Creaste repositorio ECR `despachos-api` `[ENCARGO IE2]`
- [ ] Anotaste el ECR Registry URI: `<ACCOUNT_ID>.dkr.ecr.us-east-1.amazonaws.com`
- [ ] **Captura:** 3 repos visibles en ECR Console `[ENCARGO IE2]` `[PRES IE9]`

> **Nota:** El primer push de imágenes lo hará automáticamente el pipeline de GitHub Actions al hacer push a `main`. No necesitas hacer build/push manual.

---

### 🔲 FASE 2 — Networking (VPC, Subredes, Security Groups)

#### VPC y Subredes
- [ ] Identificaste la VPC a usar (puede ser la default de Academy) `[ENCARGO IE1]`
- [ ] Tienes **mínimo 2 subredes públicas** en zonas distintas `[ENCARGO IE1]`
  - Ej: `us-east-1a` y `us-east-1b`
  - Activar "Auto-assign public IP" en ambas
- [ ] Internet Gateway adjuntado a la VPC
- [ ] Tabla de rutas tiene ruta `0.0.0.0/0` → Internet Gateway

#### Security Groups (crear 3)

**SG-ALB** (para el Load Balancer):
- Inbound: `HTTP 80` desde `0.0.0.0/0`
- Outbound: All traffic

**SG-Frontend** (para el ECS task del frontend):
- Inbound: `TCP 80` **solo desde SG-ALB**
- Outbound: All traffic

**SG-Backend** (compartido entre ventas-api y despachos-api):
- Inbound: `TCP 8080` **solo desde SG-Frontend**
- Inbound: `TCP 8081` **solo desde SG-Frontend**
- Outbound: All traffic

- [ ] Creaste SG-ALB `[ENCARGO IE1]`
- [ ] Creaste SG-Frontend (inbound solo desde SG-ALB) `[ENCARGO IE1]`
- [ ] Creaste SG-Backend (inbound solo desde SG-Frontend) `[ENCARGO IE1]`
- [ ] **Captura:** reglas de inbound de cada SG `[PRES IE8]`

> ⚠️ **CRÍTICO para la defensa:** nunca pongas `0.0.0.0/0` en inbound del SG del backend. El profesor preguntará esto.

---

### 🔲 FASE 3 — Roles IAM

#### Crear ecsTaskExecutionRole
1. IAM → Roles → Create role
2. Trusted entity: **AWS service → Elastic Container Service Task**
3. Adjuntar política: `AmazonECSTaskExecutionRolePolicy`
4. Nombre del rol: `ecsTaskExecutionRole`

> Si el rol ya existe en Academy, úsalo directamente.

- [ ] Existe el rol `ecsTaskExecutionRole` con la política adjunta `[ENCARGO IE1]`
- [ ] **Captura:** rol con políticas adjuntas `[PRES IE8]`

---

### 🔲 FASE 4 — Parámetros SSM (Secrets de base de datos)

Los backends leen los secrets de DB desde **AWS SSM Parameter Store** (ver `ecs/task-def-ventas.json`).

Crear los 4 parámetros con tipo `SecureString`:

```bash
aws ssm put-parameter --name "/prueba3/DB_ENDPOINT" --value "<endpoint-RDS>" \
  --type SecureString --region us-east-1

aws ssm put-parameter --name "/prueba3/DB_NAME" --value "prueba3_db" \
  --type SecureString --region us-east-1

aws ssm put-parameter --name "/prueba3/DB_USERNAME" --value "appuser" \
  --type SecureString --region us-east-1

aws ssm put-parameter --name "/prueba3/DB_PASSWORD" --value "<tu-password>" \
  --type SecureString --region us-east-1
```

- [ ] Parámetro `/prueba3/DB_ENDPOINT` creado en SSM `[ENCARGO IE5]`
- [ ] Parámetro `/prueba3/DB_NAME` creado en SSM `[ENCARGO IE5]`
- [ ] Parámetro `/prueba3/DB_USERNAME` creado en SSM `[ENCARGO IE5]`
- [ ] Parámetro `/prueba3/DB_PASSWORD` creado en SSM `[ENCARGO IE5]`

> Recuerda adjuntar `AmazonSSMReadOnlyAccess` (o `ssm:GetParameters`) al rol `ecsTaskExecutionRole` para que ECS pueda leer estos parámetros.

---

### 🔲 FASE 5 — Base de datos RDS MySQL

- [ ] Creaste instancia RDS MySQL 8.0 en la misma VPC `[ENCARGO IE1]`
  - DB instance class: `db.t3.micro` (suficiente para Academy)
  - SG: uno que permita `TCP 3306` **solo desde SG-Backend**
  - Public access: **No**
- [ ] Creaste la base de datos inicial (`prueba3_db`)
- [ ] Anotaste el endpoint RDS → se usa en el parámetro SSM `/prueba3/DB_ENDPOINT`

---

### 🔲 FASE 6 — Cluster ECS + Task Definitions

#### Crear el cluster

```bash
# Desde AWS CLI o usar la consola:
# ECS → Clusters → Create cluster → nombre: mi-cluster → Fargate
aws ecs create-cluster --cluster-name mi-cluster --region us-east-1
```

- [ ] Cluster `mi-cluster` creado con Fargate `[ENCARGO IE1]`

#### Habilitar Service Connect (namespace)
- En el cluster `mi-cluster` → **Service Connect** → habilitar namespace: `mi-cluster`
- Esto permite que los contenedores se comuniquen por nombre (`ventas-api`, `despachos-api`)

- [ ] Service Connect habilitado con namespace `mi-cluster`

#### Crear los Log Groups en CloudWatch

```bash
aws logs create-log-group --log-group-name /ecs/frontend-despacho --region us-east-1
aws logs create-log-group --log-group-name /ecs/ventas-api --region us-east-1
aws logs create-log-group --log-group-name /ecs/despachos-api --region us-east-1
```

- [ ] Log groups creados en CloudWatch `[ENCARGO IE6]`

#### Registrar las Task Definitions

Primero editar los archivos `ecs/task-def-*.json` reemplazando `<ACCOUNT_ID>` con tu Account ID real:

```bash
# Ver tu Account ID:
aws sts get-caller-identity --query Account --output text
```

Luego registrar cada task definition:

```bash
aws ecs register-task-definition \
  --cli-input-json file://ecs/task-def-frontend.json --region us-east-1

aws ecs register-task-definition \
  --cli-input-json file://ecs/task-def-ventas.json --region us-east-1

aws ecs register-task-definition \
  --cli-input-json file://ecs/task-def-despachos.json --region us-east-1
```

- [ ] Task Definition `frontend-despacho` registrada `[ENCARGO IE1]`
- [ ] Task Definition `ventas-api` registrada `[ENCARGO IE1]`
- [ ] Task Definition `despachos-api` registrada `[ENCARGO IE1]`

---

### 🔲 FASE 7 — ALB (Application Load Balancer)

1. EC2 → Load Balancers → Create → **Application Load Balancer**
2. Scheme: **Internet-facing**
3. Subredes: las 2 públicas
4. SG: SG-ALB
5. Crear **Target Group** para frontend:
   - Target type: **IP** (Fargate usa IPs)
   - Protocol: HTTP · Port: 80
   - Health check path: `/`
6. Crear **Listener** en puerto 80 → apuntar al Target Group del frontend

- [ ] ALB creado (Internet-facing) `[ENCARGO IE2]`
- [ ] Target Group del frontend creado (tipo IP, puerto 80) `[ENCARGO IE2]`
- [ ] Listener en puerto 80 creado `[ENCARGO IE2]`
- [ ] **Captura:** Target Group con targets `healthy` `[PRES IE8]`

---

### 🔲 FASE 8 — ECS Services

Crear 3 servicios en el cluster `mi-cluster`:

#### Service: ventas-api-service
- Launch type: Fargate
- Task Definition: `ventas-api`
- Desired count: **2**
- VPC: la tuya · Subredes: las 2 públicas
- SG: SG-Backend
- **Service Connect habilitado** → puerto `8080` → nombre de descubrimiento: `ventas-api`

#### Service: despachos-api-service
- Task Definition: `despachos-api`
- Desired count: **2**
- SG: SG-Backend
- **Service Connect habilitado** → puerto `8081` → nombre: `despachos-api`

#### Service: frontend-despacho-service
- Task Definition: `frontend-despacho`
- Desired count: **2**
- SG: SG-Frontend
- **Service Connect habilitado** (como cliente — puede llamar a ventas-api y despachos-api)
- Load balancer: adjuntar al Target Group del ALB que creaste

> ⚠️ **Importante:** crear primero los servicios de backend (ventas-api-service y despachos-api-service) antes del frontend, para que el Service Connect DNS ya esté disponible.

- [ ] Service `ventas-api-service` creado y en estado `RUNNING` `[ENCARGO IE1]`
- [ ] Service `despachos-api-service` creado y en estado `RUNNING` `[ENCARGO IE1]`
- [ ] Service `frontend-despacho-service` creado y adjuntado al ALB `[ENCARGO IE1]`
- [ ] **Captura:** 3 servicios en estado `ACTIVE` con tasks `RUNNING` `[PRES IE8]`

---

### 🔲 FASE 9 — GitHub Secrets (para los pipelines)

En GitHub → Settings → Secrets and variables → Actions, agregar:

| Secret | Valor |
|---|---|
| `AWS_ACCESS_KEY_ID` | De AWS Academy → AWS Details |
| `AWS_SECRET_ACCESS_KEY` | De AWS Academy → AWS Details |
| `AWS_SESSION_TOKEN` | De AWS Academy → AWS Details |

> **Eso es todo.** Los nombres del cluster y servicios están en los archivos `.yml` directamente (`mi-cluster`, `frontend-despacho-service`, etc.).

- [ ] Los 3 secrets de AWS están configurados en GitHub `[ENCARGO IE5]` `[CRÍTICO]`
- [ ] **Captura:** GitHub Secrets tab con los nombres (sin mostrar valores) `[ENCARGO IE5]`

---

### 🔲 FASE 10 — Primer deploy y validación del pipeline

```bash
# Hacer un commit con cualquier cambio para disparar los workflows:
git add .
git commit -m "chore: trigger initial ECS deployment"
git push origin main
```

- [ ] Workflow `CI/CD Frontend Despacho → ECS` ejecutado en verde `[ENCARGO IE4]` `[CRÍTICO]`
- [ ] Workflow `CI/CD Backend Ventas → ECS` ejecutado en verde `[ENCARGO IE4]`
- [ ] Workflow `CI/CD Backend Despachos → ECS` ejecutado en verde `[ENCARGO IE4]`
- [ ] Imágenes con tag `:latest` y `:<sha>` visibles en ECR `[PRES IE9]`
- [ ] **Captura:** 3 workflows en verde en GitHub Actions `[PRES IE9]`

---

### 🔲 FASE 11 — Autoscaling ECS

Para cada servicio (frontend, ventas, despachos):
1. ECS → Cluster → Service → **Update service**
2. Service Auto Scaling → Add scaling policy
3. Policy type: **Target tracking**
4. Metric: `ECSServiceAverageCPUUtilization`
5. Target value: `50`
6. Min capacity: `1` · Max capacity: `4`

- [ ] Autoscaling configurado en `frontend-despacho-service` `[ENCARGO IE3]`
- [ ] Autoscaling configurado en `ventas-api-service` `[ENCARGO IE3]`
- [ ] Autoscaling configurado en `despachos-api-service` `[ENCARGO IE3]`
- [ ] **Captura:** política de autoscaling en la consola `[PRES IE8]`

---

### 🔲 FASE 12 — Validación funcional end-to-end

```bash
# Obtener el DNS del ALB:
aws elbv2 describe-load-balancers \
  --query 'LoadBalancers[*].DNSName' --output text --region us-east-1

# Verificar que el frontend carga:
curl http://<alb-dns>.us-east-1.elb.amazonaws.com/

# Verificar que los backends responden via nginx proxy:
curl http://<alb-dns>.us-east-1.elb.amazonaws.com/api/ventas/api/v1/ventas
curl http://<alb-dns>.us-east-1.elb.amazonaws.com/api/despachos/api/v1/despachos
```

- [ ] Frontend accesible desde browser vía URL del ALB `[ENCARGO IE7]`
- [ ] Tabla de Ventas carga datos reales desde la API `[ENCARGO IE7]`
- [ ] Tabla de Despachos carga datos reales desde la API `[ENCARGO IE7]`
- [ ] Crear un despacho desde la UI → se guarda en BD `[ENCARGO IE7]`
- [ ] Logs visibles en CloudWatch `/ecs/frontend-despacho` `/ecs/ventas-api` `/ecs/despachos-api` `[ENCARGO IE6]`
- [ ] **Captura:** browser con frontend funcionando desde URL del ALB `[PRES]`
- [ ] **Captura:** logs en CloudWatch con contenido real `[PRES IE9]`

---

### 🔲 FASE 13 — Secretos en historial Git

```bash
# Verificar que no hay IPs ni credenciales en el historial:
git log --all --full-history -- "**/.env"
git grep -i "192.168" $(git log --pretty=format:'%H')
```

- [ ] No hay archivos `.env` con credenciales en el historial de commits `[CRÍTICO]`
- [ ] No hay IPs hardcodeadas en el código `[ENCARGO IE5]`

---

## Resumen de pendientes en AWS

```
□ Fase 1  — Crear 3 repos ECR
□ Fase 2  — VPC, Subredes, 3 Security Groups
□ Fase 3  — Rol ecsTaskExecutionRole (+ permisos SSM)
□ Fase 4  — 4 parámetros SSM con credenciales de BD
□ Fase 5  — RDS MySQL (misma VPC, sin acceso público)
□ Fase 6  — Cluster ECS mi-cluster + Service Connect + 3 Log Groups + 3 Task Definitions
□ Fase 7  — ALB + Target Group + Listener
□ Fase 8  — 3 ECS Services (backends primero, frontend después)
□ Fase 9  — 3 secrets en GitHub (AWS_ACCESS_KEY_ID, SECRET, SESSION_TOKEN)
□ Fase 10 — git push → validar 3 workflows en verde
□ Fase 11 — Autoscaling en los 3 services
□ Fase 12 — Validación funcional end-to-end
□ Fase 13 — Verificar que no hay secretos en git log
```

---

## Orden recomendado (optimizado para tiempos de Academy)

```
Sesión 1 (~2 h)
├── Fases 1-3: ECR + Networking + IAM
├── Fase 4: SSM Parameters
└── Fase 5: RDS

Sesión 2 (~2 h)
├── Fase 6: Cluster + Task Definitions
├── Fase 7: ALB
└── Fase 8: ECS Services

Sesión 3 (~1 h)
├── Fase 9: GitHub Secrets
├── Fase 10: Primer deploy + validar pipelines
├── Fase 11: Autoscaling
└── Fase 12: Validación funcional

Cierre
└── Fase 13: Limpieza + capturas + README + presentación
```

> ⚠️ **Recordatorio Academy:** las credenciales AWS expiran cada ~4 h. Al renovar el lab, actualiza los 3 secrets en GitHub Actions.
