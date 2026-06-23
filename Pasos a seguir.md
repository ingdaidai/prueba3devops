# EP3 — Guía completa: Orquestación y automatización en AWS

> **ISY1101 · Introducción a Herramientas DevOps**  
> Ponderación: **40% de la nota final**  
> Encargo: en parejas (20%) · Presentación: individual (80%)  
> Tecnología: **AWS ECS o AWS EKS** (decidir con tu dupla antes de empezar)

---

## Cómo usar este archivo

- Abre este `.md` en VS Code, Obsidian o cualquier editor que renderice GFM.
- Marca cada tarea completada cambiando `[ ]` por `[x]`.
- Las etiquetas `[ENCARGO]` y `[PRES]` indican qué se evalúa dónde.
- Las etiquetas `[CRÍTICO]` son errores que descuentan puntos automáticamente.

---

## Fase 0 — Antes de empezar (setup previo)

> Haz esto antes de tocar AWS. No saltes esta fase.

- [ ] Cuenta AWS Academy activa con laboratorio Learned Lab iniciado `[CRÍTICO]`
- [ ] Anotaste el tiempo restante del lab (se reinicia sólo — las credenciales expiran ~4 h)
- [ ] AWS CLI instalado → `aws --version`
- [ ] AWS CLI configurado con credenciales de Academy → `aws configure`
  - `AWS_ACCESS_KEY_ID`
  - `AWS_SECRET_ACCESS_KEY`
  - `AWS_SESSION_TOKEN` (requerido en Academy)
  - `Default region`: `us-east-1`
- [ ] Docker Desktop instalado y corriendo → `docker ps`
- [ ] Git configurado → `git config --global user.name` y `user.email`
- [ ] Tienes el código del frontend y backend de EP2 con sus `Dockerfile` funcionando `[CRÍTICO]`
- [ ] Decidiste con tu dupla: **¿ECS o EKS?** `[CRÍTICO]`
  - ECS Fargate → más simple, recomendado si es primera vez
  - EKS → más control y potente, pero tarda más en configurar (~20 min solo el cluster)
- [ ] kubectl instalado (solo si usas EKS) → `kubectl version --client`
- [ ] eksctl instalado (solo si usas EKS) → `eksctl version`

---

## Fase 1 — Amazon ECR (repositorio de imágenes)

> Sin las imágenes en ECR no puedes desplegar nada. Empieza aquí.

- [ ] Creaste repositorio ECR para el **frontend** `[ENCARGO IE2]`
  - AWS Console → ECR → Create repository → nombre: `frontend` → Private
- [ ] Creaste repositorio ECR para el **backend** `[ENCARGO IE2]`
  - Igual que el anterior → nombre: `backend`
- [ ] Anotaste las URIs de ambos repositorios → `<ACCOUNT_ID>.dkr.ecr.us-east-1.amazonaws.com/frontend`
- [ ] Login a ECR desde terminal:
  ```bash
  aws ecr get-login-password --region us-east-1 \
    | docker login --username AWS --password-stdin \
    <ACCOUNT_ID>.dkr.ecr.us-east-1.amazonaws.com
  ```
- [ ] Build imagen frontend → `docker build -t frontend ./frontend`
- [ ] Tag y push imagen frontend:
  ```bash
  docker tag frontend:latest <ECR_URI>/frontend:latest
  docker push <ECR_URI>/frontend:latest
  ```
- [ ] Build imagen backend → `docker build -t backend ./backend`
- [ ] Tag y push imagen backend:
  ```bash
  docker tag backend:latest <ECR_URI>/backend:latest
  docker push <ECR_URI>/backend:latest
  ```
- [ ] **Captura:** ambas imágenes visibles en ECR con tag `:latest` `[ENCARGO IE2]` `[PRES IE9]`

---

## Fase 2 — Networking (VPC, Subredes, Security Groups)

> La base de toda la arquitectura. Un error aquí rompe todo lo demás.

- [ ] Identificaste o creaste la VPC a usar `[ENCARGO IE1]`
  - Puedes usar la VPC por defecto de Academy o crear una con CIDR `10.0.0.0/16`
- [ ] Creaste **mínimo 2 subredes públicas** en zonas distintas `[ENCARGO IE1]`
  - Ejemplo: `10.0.1.0/24` en `us-east-1a` y `10.0.2.0/24` en `us-east-1b`
  - Activa "Auto-assign public IP" en subredes públicas
- [ ] Internet Gateway creado y adjuntado a la VPC
- [ ] Tabla de rutas de subredes públicas tiene ruta `0.0.0.0/0` → Internet Gateway
- [ ] **Security Group: ALB** `[ENCARGO IE1]`
  - Inbound: `HTTP 80` desde `0.0.0.0/0`
  - Outbound: `All traffic`
- [ ] **Security Group: Frontend** `[ENCARGO IE1]`
  - Inbound: puerto del contenedor (ej. `3000`) solo desde el SG del ALB
  - Outbound: `All traffic`
- [ ] **Security Group: Backend** `[ENCARGO IE1]`
  - Inbound: puerto de la API (ej. `8080`) solo desde el SG del Frontend
  - Outbound: `All traffic`
- [ ] **Captura:** VPC, subredes y reglas de cada SG `[PRES IE8]`

> **Tip:** Nunca pongas `0.0.0.0/0` como inbound en el SG del backend.  
> El profesor preguntará específicamente sobre esto en la defensa técnica.

---

## Fase 3 — Roles IAM

> El clúster necesita permisos para actuar en AWS. Sin esto, nada despliega.

### Si usas ECS

- [ ] Creaste el rol **ecsTaskExecutionRole** `[ENCARGO IE1]`
  - IAM → Roles → Create role → AWS service → Elastic Container Service Task
  - Política adjunta: `AmazonECSTaskExecutionRolePolicy`
- [ ] (Opcional) Creaste un **ecsTaskRole** si el backend necesita acceder a S3, SQS u otros servicios
- [ ] **Captura:** roles IAM con sus políticas adjuntas `[PRES IE8]`

### Si usas EKS

- [ ] Creaste el rol **AmazonEKSClusterRole** con política `AmazonEKSClusterPolicy`
- [ ] Creaste el rol **AmazonEKSNodeRole** con políticas:
  - `AmazonEKSWorkerNodePolicy`
  - `AmazonEC2ContainerRegistryReadOnly`
  - `AmazonEKS_CNI_Policy`
- [ ] **Captura:** roles IAM con sus políticas adjuntas `[PRES IE8]`

---

## Fase 4 — Configuración del clúster

### Opción A: AWS ECS

- [ ] Creaste el clúster ECS `[ENCARGO IE1]`
  - ECS → Clusters → Create cluster → nombre: `mi-cluster`
  - Tipo: **Fargate** (recomendado en Academy)
- [ ] Creaste **Task Definition** para el frontend `[ENCARGO IE1]`
  - Container image: URI de ECR del frontend
  - Port mappings: puerto del contenedor (ej. `3000`)
  - Environment variables: las que necesite tu app
  - Log configuration: CloudWatch Logs → log group `/ecs/frontend`
  - Task execution role: `ecsTaskExecutionRole`
- [ ] Creaste **Task Definition** para el backend `[ENCARGO IE1]`
  - Container image: URI de ECR del backend
  - Port mappings: puerto de la API (ej. `8080`)
  - Environment variables: `DB_URL`, `PORT`, etc.
  - Log configuration: CloudWatch Logs → log group `/ecs/backend`
- [ ] Creaste **Service** para el frontend `[ENCARGO IE1]`
  - Launch type: Fargate
  - Desired count: 2
  - VPC y subredes públicas
  - SG del frontend
  - Adjuntado al Target Group del ALB (ver Fase 5)
- [ ] Creaste **Service** para el backend `[ENCARGO IE1]`
  - Desired count: 2
  - SG del backend
- [ ] **Captura:** tasks en estado `RUNNING` en la consola de ECS `[ENCARGO IE1]` `[PRES IE8]`

### Opción B: AWS EKS

- [ ] Creaste el clúster EKS `[ENCARGO IE1]`
  ```bash
  eksctl create cluster \
    --name mi-cluster \
    --region us-east-1 \
    --nodes 2 \
    --node-type t3.medium
  # Tarda ~15-20 minutos
  ```
- [ ] Actualizaste el kubeconfig:
  ```bash
  aws eks update-kubeconfig --region us-east-1 --name mi-cluster
  kubectl get nodes  # deben aparecer en estado Ready
  ```
- [ ] Creaste `frontend-deployment.yaml` `[ENCARGO IE1]`
  ```yaml
  apiVersion: apps/v1
  kind: Deployment
  metadata:
    name: frontend
  spec:
    replicas: 2
    selector:
      matchLabels:
        app: frontend
    template:
      metadata:
        labels:
          app: frontend
      spec:
        containers:
        - name: frontend
          image: <ECR_URI>/frontend:latest
          ports:
          - containerPort: 3000
          env:
          - name: BACKEND_URL
            value: "http://backend-service:8080"
  ```
- [ ] Creaste `frontend-service.yaml` con `type: LoadBalancer` `[ENCARGO IE1]`
- [ ] Creaste `backend-deployment.yaml` con `replicas: 2` `[ENCARGO IE1]`
- [ ] Creaste `backend-service.yaml` con `type: ClusterIP` (interno) `[ENCARGO IE1]`
- [ ] Aplicaste todos los manifiestos:
  ```bash
  kubectl apply -f frontend-deployment.yaml
  kubectl apply -f frontend-service.yaml
  kubectl apply -f backend-deployment.yaml
  kubectl apply -f backend-service.yaml
  ```
- [ ] **Captura:** `kubectl get pods -A` mostrando todos en estado `Running` `[PRES IE8]`

---

## Fase 5 — Application Load Balancer (ALB)

> El punto de entrada público de tu aplicación.

- [ ] Creaste el ALB externo `[ENCARGO IE2]`
  - EC2 → Load Balancers → Create → Application Load Balancer
  - Scheme: **Internet-facing**
  - Subredes: las 2 públicas que creaste
  - SG: el del ALB
- [ ] Creaste **Target Group** para el frontend `[ENCARGO IE2]`
  - Target type: IP (para Fargate) o Instance (para EC2/EKS)
  - Protocol: HTTP · Port: el del contenedor (ej. `3000`)
  - Health check path: `/` o `/health`
- [ ] Creaste **Listener** en puerto 80 apuntando al Target Group del frontend
- [ ] El frontend es **accesible públicamente** por el DNS del ALB `[ENCARGO IE7]`
  - `http://<alb-dns-name>.us-east-1.elb.amazonaws.com`
- [ ] La comunicación **Frontend → Backend** funciona `[ENCARGO IE7]`
  - ECS: via AWS Service Connect o IP privada del task
  - EKS: via DNS interno del service → `http://backend-service:8080`
- [ ] **Captura:** Target Group con targets en estado `healthy` `[PRES IE8]`
- [ ] **Captura:** browser mostrando el frontend cargado desde la URL del ALB `[PRES]`

---

## Fase 6 — Autoscaling

> La app debe escalar sola. Vale 10% del encargo.

### Si usas ECS — Target Tracking

- [ ] Habilitaste Auto Scaling en el Service del frontend `[ENCARGO IE3]`
  - ECS → Service → Update service → Service Auto Scaling → Add scaling policy
  - Policy type: Target tracking
  - Metric: `ECSServiceAverageCPUUtilization`
  - Target value: `50`
  - Min capacity: `1` · Max capacity: `4`
- [ ] Lo mismo para el Service del backend `[ENCARGO IE3]`
- [ ] **Captura:** política de autoscaling configurada en la consola `[ENCARGO IE3]` `[PRES IE8]`

### Si usas EKS — Horizontal Pod Autoscaler (HPA)

- [ ] Instalaste Metrics Server:
  ```bash
  kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
  kubectl top nodes  # verificar que funciona
  ```
- [ ] Creaste HPA para el frontend `[ENCARGO IE3]`:
  ```bash
  kubectl autoscale deployment frontend --cpu-percent=50 --min=1 --max=4
  ```
- [ ] Creaste HPA para el backend `[ENCARGO IE3]`:
  ```bash
  kubectl autoscale deployment backend --cpu-percent=50 --min=1 --max=4
  ```
- [ ] **Captura:** `kubectl get hpa` mostrando los valores configurados `[ENCARGO IE3]` `[PRES IE8]`
- [ ] (Recomendado) Simulaste carga para demostrar el escalado:
  ```bash
  # Apache Bench — instalar con: sudo apt install apache2-utils
  ab -n 2000 -c 100 http://<alb-url>/
  ```
- [ ] **Captura:** número de tasks/pods aumentando durante la carga `[PRES IE8]`

> **Para la defensa:** justifica el umbral del 50% argumentando que permite absorber  
> picos de tráfico mientras el nuevo pod/task arranca, evitando saturación.

---

## Fase 7 — Pipeline CI/CD con GitHub Actions

> Automatiza build → push → deploy. Vale 15% del encargo y 25% de la presentación.

### Configuración de Secrets en GitHub

- [ ] Abriste Settings → Secrets and variables → Actions en tu repo `[ENCARGO IE5]`
- [ ] Agregaste los siguientes secrets `[ENCARGO IE5]` `[CRÍTICO]`:

| Secret | Valor |
|---|---|
| `AWS_ACCESS_KEY_ID` | De AWS Academy → AWS Details |
| `AWS_SECRET_ACCESS_KEY` | De AWS Academy → AWS Details |
| `AWS_SESSION_TOKEN` | De AWS Academy → AWS Details |
| `AWS_REGION` | `us-east-1` |
| `ECR_REGISTRY` | `<ACCOUNT_ID>.dkr.ecr.us-east-1.amazonaws.com` |

### Archivo del pipeline

- [ ] Creaste `.github/workflows/deploy.yml` en el repositorio del frontend `[ENCARGO IE4]`
- [ ] Creaste `.github/workflows/deploy.yml` en el repositorio del backend `[ENCARGO IE4]`

#### Plantilla para ECS:

```yaml
name: Deploy to ECS

on:
  push:
    branches: [main]

env:
  AWS_REGION: ${{ secrets.AWS_REGION }}
  ECR_REGISTRY: ${{ secrets.ECR_REGISTRY }}
  ECR_REPOSITORY: frontend        # cambiar a "backend" en el otro repo
  ECS_SERVICE: frontend-service   # nombre de tu service en ECS
  ECS_CLUSTER: mi-cluster
  CONTAINER_NAME: frontend

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout código
        uses: actions/checkout@v3

      - name: Configurar credenciales AWS
        uses: aws-actions/configure-aws-credentials@v2
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-session-token: ${{ secrets.AWS_SESSION_TOKEN }}
          aws-region: ${{ env.AWS_REGION }}

      - name: Login a Amazon ECR
        id: login-ecr
        uses: aws-actions/amazon-ecr-login@v1

      - name: Build y push imagen Docker
        id: build-image
        run: |
          IMAGE_TAG=${{ github.sha }}
          docker build -t $ECR_REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG .
          docker push $ECR_REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG
          echo "image=$ECR_REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG" >> $GITHUB_OUTPUT

      - name: Deploy a ECS
        run: |
          aws ecs update-service \
            --cluster ${{ env.ECS_CLUSTER }} \
            --service ${{ env.ECS_SERVICE }} \
            --force-new-deployment \
            --region ${{ env.AWS_REGION }}
```

#### Plantilla para EKS (step de deploy diferente):

```yaml
      - name: Actualizar kubeconfig
        run: |
          aws eks update-kubeconfig --region ${{ env.AWS_REGION }} --name mi-cluster

      - name: Deploy a EKS
        run: |
          kubectl set image deployment/frontend \
            frontend=${{ steps.build-image.outputs.image }}
          kubectl rollout status deployment/frontend
```

### Verificación del pipeline

- [ ] Hiciste un commit a `main` y verificaste que el workflow se dispara `[ENCARGO IE4]`
- [ ] El workflow completa todos los steps en verde `[ENCARGO IE4]`
- [ ] El deploy se reflejó en el clúster (nuevo task/pod corriendo) `[ENCARGO IE4]`
- [ ] **Captura:** workflow completo en verde con todos los steps `[PRES IE9]` `[CRÍTICO para IE9]`
- [ ] **Captura:** logs del pipeline expandidos mostrando tiempos de ejecución `[PRES IE9]`
- [ ] Probaste recuperación: hiciste push de un cambio pequeño y el pipeline lo deployó solo `[ENCARGO IE7]`

> **Problema frecuente en Academy:** los secrets de AWS expiran con el lab (~4 h).  
> Si el pipeline falla con errores de autenticación, actualiza los 3 secrets de AWS en GitHub.

---

## Fase 8 — Gestión de Secrets y credenciales

> Vale solo 5% del encargo, pero un error aquí puede ser descuento automático.

- [ ] El archivo `.env` está en `.gitignore` y nunca se hizo commit `[ENCARGO IE5]` `[CRÍTICO]`
- [ ] Las variables de entorno sensibles se leen desde GitHub Secrets en el pipeline `[ENCARGO IE5]`
- [ ] Las variables de entorno en el contenedor usan referencias, no valores hardcodeados:
  - ECS: usa `secrets` en la Task Definition apuntando a Secrets Manager o Parameter Store
  - EKS: usa `secretKeyRef` en el YAML del Deployment
- [ ] Verificaste con `git log` que no hay credenciales en el historial de commits `[CRÍTICO]`
- [ ] **Captura:** GitHub Secrets tab mostrando los nombres (nunca los valores) `[ENCARGO IE5]`

---

## Fase 9 — Logs y métricas

> Vale 10% del encargo. También es evidencia clave para la presentación.

- [ ] Los logs del frontend son visibles en CloudWatch (ECS) o `kubectl logs` (EKS) `[ENCARGO IE6]`
  - ECS: CloudWatch → Log groups → `/ecs/frontend`
  - EKS: `kubectl logs deployment/frontend`
- [ ] Los logs del backend son visibles `[ENCARGO IE6]`
- [ ] Analizaste los logs: errores, tiempos de respuesta, requests `[ENCARGO IE6]`
- [ ] Tienes métricas del pipeline: tiempo total de ejecución, steps más lentos `[ENCARGO IE6]`
- [ ] **Captura:** logs en CloudWatch o terminal con contenido real `[PRES IE9]`

---

## Fase 10 — Validación funcional end-to-end

> Vale 10% del encargo. Demuestra que todo el sistema funciona junto.

- [ ] Frontend accesible desde el browser vía URL del ALB `[ENCARGO IE7]` `[PRES]`
- [ ] Backend respondiendo requests:
  ```bash
  curl http://<alb-url>/api/health
  # debe retornar HTTP 200
  ```
- [ ] Comunicación Frontend → Backend operativa (realiza una acción en la UI que llame a la API) `[ENCARGO IE7]`
- [ ] Logs visibles y coherentes en CloudWatch o kubectl `[ENCARGO IE7]`
- [ ] El sistema se recupera ante un redeploy (push un cambio, espera el pipeline, verifica) `[ENCARGO IE7]`
- [ ] **Captura:** browser con frontend funcionando + una llamada API exitosa `[PRES]`

---

## Fase 11 — Documentación de los repositorios

> El encargo se entrega como repositorios. Sin README completo, descuento en IE4/IE5.

- [ ] `README.md` en el repo del frontend explica `[ENCARGO]`:
  - Qué es el proyecto
  - Cómo configurar las variables de entorno
  - Cómo buildear la imagen Docker
  - Cómo hacer deploy manualmente
  - Descripción del pipeline CI/CD
- [ ] `README.md` en el repo del backend con la misma estructura `[ENCARGO]`
- [ ] Los commits del repo son descriptivos (`feat:`, `fix:`, `chore:`) `[ENCARGO]`
- [ ] No hay archivos `.env`, credenciales ni `node_modules` en el repo `[CRÍTICO]`
- [ ] Subiste los repositorios al AVA antes del plazo `[CRÍTICO]`

---

## Fase 12 — Preparación de la presentación

> La presentación vale el **80% de tu EP3**. Es evaluada de forma individual.  
> Duración: 10-15 minutos por dupla. Es en vivo — no se aceptan videos pregrabados.

### Slides requeridos

- [ ] **Slide 1 — Portada:** nombres, asignatura, fecha `[PRES IE11]`
- [ ] **Slide 2 — Arquitectura general** (diagrama con VPC, subredes, ALB, clúster, ECR, GitHub) `[PRES IE8]`
- [ ] **Slide 3 — Justificación de ECS o EKS** (por qué eligieron esa tecnología, ventajas en su caso) `[PRES IE8]`
- [ ] **Slide 4 — Configuración del clúster** (nodos/Fargate, roles IAM, SG — con capturas) `[PRES IE8]`
- [ ] **Slide 5 — Despliegue de servicios** (Task Definition o YAML, imágenes ECR, variables de entorno) `[PRES IE8]`
- [ ] **Slide 6 — Pipeline CI/CD** (YAML del workflow, captura en verde, flujo build→push→deploy) `[PRES IE9]`
- [ ] **Slide 7 — Autoscaling** (política o HPA, justificación del umbral, captura o simulación de carga) `[PRES IE8]`
- [ ] **Slide 8 — Demo en vivo** (frontend accesible, logs de CloudWatch/kubectl, comunicación Front→Back) `[PRES]`
- [ ] **Slide 9 — Análisis crítico** (problemas encontrados, decisiones técnicas tomadas, lecciones aprendidas) `[PRES IE10]`
- [ ] **Slide 10 — Proyección productiva para Innovatech Chile** (HTTPS, multi-region, monitoreo real, WAF) `[PRES]`

### Preparación para la defensa técnica (IE10 — 25% de la presentación)

El profesor puede preguntarte **cualquier cosa** sobre la solución, aunque no la hayas implementado tú.  
Estudia estas preguntas típicas:

- [ ] ¿Qué hace exactamente el rol `ecsTaskExecutionRole`? ¿Por qué es necesario?
- [ ] ¿Cuál es la diferencia entre un Task y un Service en ECS?
- [ ] ¿Por qué usaron Fargate en vez de EC2? (o viceversa)
- [ ] ¿Cómo funciona el Target Tracking en ECS? ¿Qué pasa cuando baja la carga?
- [ ] ¿Qué es el HPA de Kubernetes y cómo decide escalar?
- [ ] ¿Por qué el backend tiene SG restrictivo y el frontend no?
- [ ] ¿Qué pasaría si el pipeline falla en el step de deploy? ¿La app sigue corriendo?
- [ ] ¿Cómo se comunica el frontend con el backend dentro del clúster?
- [ ] ¿Qué son los logs de CloudWatch y para qué sirven en producción?
- [ ] ¿Cómo proyectarían esto a producción real para Innovatech Chile?

### Aspectos formales

- [ ] Presentación en PowerPoint o PDF `[PRES IE11]`
- [ ] Lenguaje técnico profesional en español `[PRES IE11]`
- [ ] Tienes capturas de respaldo por si la demo falla en vivo `[PRES]`
- [ ] Subiste la presentación al AVA antes de la clase `[CRÍTICO]`

---

## Resumen de la rúbrica

### Encargo (en parejas) — 20% del EP3

| Indicador | Peso | Qué evalúa |
|---|---|---|
| IE1 — Configuración del clúster | 25% | VPC, SG, IAM, nodos/Fargate funcional |
| IE2 — Despliegue Front + Back | 25% | ECR, variables, puertos, balanceador |
| IE3 — Autoscaling | 10% | Política configurada, métricas, umbral justificado |
| IE4 — Pipeline CI/CD | 15% | build → push → deploy automatizado |
| IE5 — Secrets y credenciales | 5% | Sin credenciales expuestas en código |
| IE6 — Logs y métricas | 10% | CloudWatch/kubectl logs con análisis |
| IE7 — Validación funcional | 10% | Front→Back operativo, recovery demostrado |

### Presentación (individual) — 80% del EP3

| Indicador | Peso | Qué evalúa |
|---|---|---|
| IE8 — Fundamentos de orquestación | 25% | Clúster, nodos, autoscaling, balanceo con profundidad |
| IE9 — Demo pipeline CI/CD | 25% | Muestra build→push→deploy con evidencia clara |
| IE10 — Defensa técnica | 25% | Responde preguntas con precisión y dominio total |
| IE11 — Claridad y estructura | 25% | Presentación profesional, clara, ordenada |

### Escala de logro

| Nivel | % | Descripción |
|---|---|---|
| Muy buen desempeño | 100% | Logro de todos los aspectos del indicador |
| Buen desempeño | 80% | Alto desempeño con pequeñas omisiones |
| Desempeño aceptable | 60% | Logro de elementos básicos con omisiones o errores |
| Desempeño incipiente | 30% | Omisiones importantes, no es considerado competente |
| Desempeño no logrado | 0% | Ausencia o incorrecto desempeño |

---

## Orden recomendado de trabajo

```
Día 1 (en clase — TAITE 7)
├── Fase 0: setup y decisión ECS vs EKS
├── Fase 1: ECR + push de imágenes
├── Fase 2: VPC y Security Groups
└── Fase 3: Roles IAM

Día 1-2 (trabajo personal)
├── Fase 4: clúster + Task Definitions o Deployments
├── Fase 5: ALB + acceso público al frontend
├── Fase 6: autoscaling
└── Fase 7: pipeline CI/CD (esto lleva más tiempo)

Día 2-3 (cierre)
├── Fase 8: secrets y limpieza del repo
├── Fase 9: logs y métricas
├── Fase 10: validación end-to-end
├── Fase 11: README y entrega al AVA
└── Fase 12: slides + preparar defensa técnica
```

---

*Generado como guía de referencia para EP3 — ISY1101 · Duoc UC 2025*
