# 🖥️ Frontend Despachos - React + Vite

Aplicación web desarrollada con **React 18** y **Vite** para la gestión de despachos de Innovatech Chile.  
Desplegada en contenedores Docker sobre **AWS EC2 pública**, con pipeline CI/CD automatizado vía **GitHub Actions** y registro de imágenes en **AWS ECR**.

---

## 📋 Tabla de Contenidos

- [Tecnologías](#tecnologías)
- [Estructura del Proyecto](#estructura-del-proyecto)
- [Configuración Local](#configuración-local)
- [Docker](#docker)
- [Pipeline CI/CD](#pipeline-cicd)
- [Variables de Entorno](#variables-de-entorno)
- [Arquitectura en AWS](#arquitectura-en-aws)

---

## 🛠 Tecnologías

| Tecnología | Versión | Uso |
|---|---|---|
| React | 18.2 | Framework UI |
| Vite | 5.2 | Bundler y dev server |
| Tailwind CSS | 3.4 | Estilos |
| Axios | 1.6 | Peticiones HTTP |
| React Router | 6.24 | Navegación SPA |
| Nginx | 1.25 | Servidor web en producción |
| Docker | latest | Contenedorización |
| GitHub Actions | - | Pipeline CI/CD |
| AWS ECR | - | Registro de imágenes |
| AWS EC2 | - | Despliegue en nube |

---

## 📁 Estructura del Proyecto

```
front_despacho/
├── src/
│   ├── componentes/
│   │   ├── CrudAdmin/
│   │   │   ├── TableDespachos.jsx   # Lista de despachos
│   │   │   ├── TableCompras.jsx     # Lista de compras
│   │   │   ├── FormDespacho.jsx     # Formulario de despacho
│   │   │   ├── FormCierreDespacho.jsx
│   │   │   ├── Modal.jsx
│   │   │   ├── SearchBar.jsx
│   │   │   └── CardComponent.jsx
│   │   └── Layouts/
│   │       ├── Navbar.jsx
│   │       ├── Footer.jsx
│   │       ├── Carrusel.jsx
│   │       └── Reviews.jsx
│   ├── Routes/
│   │   └── AppRoutes.jsx
│   ├── main.jsx
│   └── index.css
├── .github/
│   └── workflows/
│       └── deploy-frontend.yml  # Pipeline CI/CD
├── Dockerfile                   # Multi-stage build (Node + Nginx)
├── docker-compose.yml           # Stack frontend
├── nginx.conf                   # Configuración Nginx + proxy
├── .env.example                 # Plantilla de variables
└── README.md
```

---

## ⚙️ Configuración Local

### Pre-requisitos
- Docker Desktop instalado
- Git

### Pasos

```bash
# 1. Clonar el repositorio
git clone <url-del-repositorio>
cd front_despacho

# 2. Crear archivo de variables de entorno
cp .env.example .env
# Editar .env → VITE_API_URL=http://IP-del-backend:8081

# 3. Levantar el contenedor
docker compose up -d

# 4. Verificar estado
docker compose ps

# 5. Ver logs
docker compose logs -f frontend
```

La app estará disponible en: `http://localhost:80`

---

## 🐳 Docker

### Dockerfile (Multi-stage Build)

El Dockerfile usa **dos etapas** para optimizar el tamaño de la imagen final:

| Etapa | Imagen base | Propósito |
|---|---|---|
| `builder` | `node:20-alpine` | Instalar dependencias y compilar con Vite |
| `runtime` | `nginx:1.25-alpine` | Servir archivos estáticos |

**Buenas prácticas aplicadas:**
- ✅ Multi-stage build (imagen final ~25MB vs ~600MB con Node)
- ✅ Usuario no root (`nginx`) por seguridad
- ✅ `npm ci --frozen-lockfile` para builds reproducibles
- ✅ Caché de capas (package.json separado del código)
- ✅ Variables de entorno en tiempo de build (`VITE_API_URL`)

### Comandos útiles

```bash
# Build manual
docker build --build-arg VITE_API_URL=http://IP-backend:8081 -t despachos-frontend:local .

# Correr contenedor
docker run -p 80:80 despachos-frontend:local

# Detener
docker compose down
```

---

## 🔄 Pipeline CI/CD

El pipeline se activa automáticamente al hacer **push a la rama `deploy`**.

### Flujo

```
push a rama deploy
        │
        ▼
┌─────────────────┐
│  1. Checkout    │  Descarga el código fuente
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  2. AWS Auth    │  Configura credenciales con GitHub Secrets
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  3. ECR Login   │  Autentica Docker con el registry privado
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  4. Build+Push  │  Compila React + empaqueta con Nginx → sube a ECR
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  5. Deploy EC2  │  SSH → pull imagen → restart contenedor
└─────────────────┘
```

### Secrets requeridos en GitHub

| Secret | Descripción |
|---|---|
| `AWS_ACCESS_KEY_ID` | Clave de acceso AWS |
| `AWS_SECRET_ACCESS_KEY` | Clave secreta AWS |
| `AWS_SESSION_TOKEN` | Token sesión (AWS Academy) |
| `AWS_REGION` | Región (ej: `us-east-1`) |
| `ECR_REGISTRY` | URL del registry ECR |
| `ECR_REPOSITORY_FRONTEND` | Nombre repo ECR (ej: `despachos-frontend`) |
| `EC2_FRONTEND_HOST` | IP pública de la EC2 frontend |
| `EC2_SSH_KEY` | Contenido del `.pem` |
| `EC2_USER` | Usuario SSH (`ec2-user` o `ubuntu`) |
| `VITE_API_URL` | URL del backend (IP privada EC2 backend) |

---

## 🔐 Variables de Entorno

| Variable | Descripción | Ejemplo |
|---|---|---|
| `VITE_API_URL` | URL base del Backend Despachos | `http://10.0.2.50:8081` |

> **Nota:** Las variables `VITE_*` son embebidas por Vite durante el `build`. Deben pasarse como `--build-arg` en el `docker build`.

---

## 🏗 Arquitectura en AWS

```
Internet
    │
    ▼
[Security Group: HTTP 80]
    │
    ▼
┌───────────────────────┐      ┌───────────────────────┐
│  EC2 Frontend (pública)│─────▶│  EC2 Backend (privada) │
│  Nginx → React SPA     │      │  Spring Boot :8081     │
│  Puerto 80 expuesto    │      │  Solo acepta del Front │
└───────────────────────┘      └──────────┬────────────┘
                                           │
                                           ▼
                                 ┌──────────────────┐
                                 │  MySQL :3306      │
                                 │  (contenedor)     │
                                 └──────────────────┘
```

- **Solo el Frontend es accesible desde Internet** (Security Group permite HTTP 80)
- El Backend está en subred privada, solo acepta tráfico del Frontend
- La comunicación Front→Back usa la **IP privada** de la EC2 backend

---

## 📝 Historial de Commits

El repositorio sigue la convención:
- `feat:` nueva funcionalidad
- `fix:` corrección de error
- `docker:` cambios Docker/Nginx
- `ci:` cambios en pipeline
- `docs:` cambios en documentación
